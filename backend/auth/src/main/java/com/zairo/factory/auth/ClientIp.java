package com.zairo.factory.auth;

import jakarta.servlet.http.HttpServletRequest;

/**
 * The caller's IP for abuse limits. Behind a reverse proxy
 * {@code getRemoteAddr()} is the proxy, so every user would share one
 * "IP" and one limit. {@code trustedProxyHops} is how many proxies in front
 * of the app append to {@code X-Forwarded-For} (1 for a single platform
 * load balancer such as Render): the client is then the entry that many
 * places from the <em>right</em> — entries further left are client-supplied
 * and spoofable. 0 ignores the header (app exposed directly).
 */
public final class ClientIp {

    private ClientIp() {
    }

    public static String of(HttpServletRequest request, int trustedProxyHops) {
        if (trustedProxyHops > 0) {
            String header = request.getHeader("X-Forwarded-For");
            if (header != null && !header.isBlank()) {
                String[] parts = header.split(",");
                int index = parts.length - trustedProxyHops;
                if (index >= 0) {
                    String candidate = parts[index].trim();
                    if (!candidate.isEmpty() && candidate.length() <= 64) {
                        return candidate;
                    }
                }
            }
        }
        String remote = request.getRemoteAddr();
        return remote == null || remote.length() > 64 ? null : remote;
    }
}
