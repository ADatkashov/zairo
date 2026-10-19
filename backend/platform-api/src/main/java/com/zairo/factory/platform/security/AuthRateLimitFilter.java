package com.zairo.factory.platform.security;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zairo.factory.auth.ClientIp;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Abuse limits on the public sign-in / registration / recovery endpoints.
 * Complements the per-email lockout in {@code LoginAttemptLimiter} and the
 * OTP limits: those protect one account, this stops one <em>caller</em> —
 * password spraying across many accounts, mass registration, e-mail bombing
 * via "forgot password" and brute force against the platform console login.
 *
 * <p>Every rule limits per client IP; rules with a {@code bodyField} also
 * limit per value of that JSON field (the e-mail / phone). Over the limit the
 * answer is 429 with {@code Retry-After}. Disabled with
 * {@code app.rate-limit.enabled=false} (the integration tests, which hammer
 * one address, do that).
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
class AuthRateLimitFilter extends OncePerRequestFilter {

    /** {@code bodyField}: JSON field to additionally limit per value (null = IP only). */
    record Rule(String name, List<String> paths, int ipLimit, long windowSeconds, String bodyField, int bodyLimit) {
    }

    static final List<Rule> RULES = List.of(
            new Rule("login", List.of("/api/v1/auth/login", "/api/v1/auth/phone/login", "/api/v1/auth/google",
                    "/api/v1/auth/apple", "/api/v1/auth/facebook", "/api/v1/auth/identities/link-with-password"),
                    30, 60, null, 0),
            // The platform console is the most valuable target and has very few legitimate users.
            new Rule("platform-login", List.of("/api/v1/platform/auth/login"), 10, 600, "email", 10),
            new Rule("register", List.of("/api/v1/auth/register", "/api/v1/auth/phone/register"),
                    20, 3600, "email", 5),
            new Rule("recovery", List.of("/api/v1/auth/forgot-password", "/api/v1/auth/reset-password",
                    "/api/v1/auth/phone/reset-password"), 10, 3600, "email", 3),
            new Rule("refresh", List.of("/api/v1/auth/refresh"), 60, 60, null, 0));

    private static final int MAX_BODY_BYTES = 8 * 1024;

    private final boolean enabled;
    private final int trustedProxyHops;
    private final FixedWindowCounter counter;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final Clock clock;

    @Autowired
    AuthRateLimitFilter(@Value("${app.rate-limit.enabled:true}") boolean enabled,
            @Value("${app.otp.trusted-proxy-hops:1}") int trustedProxyHops) {
        this(enabled, trustedProxyHops, Clock.systemUTC());
    }

    AuthRateLimitFilter(boolean enabled, int trustedProxyHops, Clock clock) {
        this.enabled = enabled;
        this.trustedProxyHops = trustedProxyHops;
        this.clock = clock;
        this.counter = new FixedWindowCounter(clock);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !enabled || !"POST".equals(request.getMethod()) || ruleFor(request.getRequestURI()) == null;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        Rule rule = ruleFor(request.getRequestURI());
        String ip = ClientIp.of(request, trustedProxyHops);
        HttpServletRequest effective = request;

        FixedWindowCounter.Result result = counter.hit("ip:" + rule.name() + ":" + ip, rule.ipLimit(),
                rule.windowSeconds());
        if (result.allowed() && rule.bodyField() != null) {
            CachedBodyRequest cached = new CachedBodyRequest(request);
            if (cached.body().length > MAX_BODY_BYTES) {
                // Sign-in bodies are tiny; a bigger one is not a real client (and could not be replayed whole).
                response.sendError(HttpServletResponse.SC_REQUEST_ENTITY_TOO_LARGE);
                return;
            }
            effective = cached;
            String value = fieldValue(cached.body(), rule.bodyField());
            if (value != null) {
                result = counter.hit("key:" + rule.name() + ":" + value.trim().toLowerCase(Locale.ROOT),
                        rule.bodyLimit(), rule.windowSeconds());
            }
        }

        if (!result.allowed()) {
            reject(request, response, result.retryAfterSeconds());
            return;
        }
        chain.doFilter(effective, response);
    }

    private static Rule ruleFor(String path) {
        for (Rule rule : RULES) {
            if (rule.paths().contains(path)) {
                return rule;
            }
        }
        return null;
    }

    private String fieldValue(byte[] body, String field) {
        try {
            JsonNode node = objectMapper.readTree(body);
            JsonNode value = node == null ? null : node.get(field);
            return value != null && value.isTextual() && value.asText().length() <= 320 ? value.asText() : null;
        } catch (IOException e) {
            return null; // not JSON — the controller answers 400 as before
        }
    }

    private void reject(HttpServletRequest request, HttpServletResponse response, long retryAfterSeconds)
            throws IOException {
        response.setStatus(429);
        response.setHeader("Retry-After", String.valueOf(retryAfterSeconds));
        response.setContentType("application/json");
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write("{\"timestamp\":\"" + Instant.now(clock) + "\",\"status\":429,"
                + "\"error\":\"Too Many Requests\",\"message\":\"Too many attempts — try again in "
                + Math.max(1, (retryAfterSeconds + 59) / 60) + " min\",\"path\":\""
                + request.getRequestURI().replace("\"", "") + "\",\"errors\":null}");
    }

    /** Replays the first {@code MAX_BODY_BYTES} of the body so the controller can still read it. */
    private static final class CachedBodyRequest extends HttpServletRequestWrapper {

        private final byte[] body;

        CachedBodyRequest(HttpServletRequest request) throws IOException {
            super(request);
            this.body = request.getInputStream().readNBytes(MAX_BODY_BYTES + 1);
        }

        byte[] body() {
            return body;
        }

        @Override
        public ServletInputStream getInputStream() {
            ByteArrayInputStream in = new ByteArrayInputStream(body);
            return new ServletInputStream() {
                @Override
                public int read() {
                    return in.read();
                }

                @Override
                public boolean isFinished() {
                    return in.available() == 0;
                }

                @Override
                public boolean isReady() {
                    return true;
                }

                @Override
                public void setReadListener(ReadListener listener) {
                    throw new UnsupportedOperationException();
                }
            };
        }
    }
}
