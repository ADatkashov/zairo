package com.zairo.factory.auth;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.stereotype.Component;

/**
 * Real SMS delivery through Twilio's Programmable Messaging REST API
 * ({@code POST /2010-04-01/Accounts/{sid}/Messages.json}) — a plain {@code
 * java.net.http.HttpClient} call, same convention as
 * FacebookGraphIdentityVerifier/{@code payment-provider}'s
 * FreedomPayHttpClient, so no Twilio SDK dependency is added.
 *
 * <p>Active only when {@code app.sms.twilio.account-sid} is set; otherwise
 * {@link LoggingOtpSender} stays the delivery channel (local dev/CI). Set
 * either {@code app.sms.twilio.from} (a Twilio phone number, E.164) or
 * {@code app.sms.twilio.messaging-service-sid}; the messaging service wins
 * when both are set.
 *
 * <p>Never logs the code or the auth token — only the destination's last
 * four digits and Twilio's message SID/error.
 */
@Component
@ConditionalOnExpression("'${app.sms.twilio.account-sid:}'.length() > 0")
class TwilioOtpSender implements OtpSenderPort {

    private static final Logger log = LoggerFactory.getLogger(TwilioOtpSender.class);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(10);

    private final HttpClient httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    private final String accountSid;
    private final String authToken;
    private final String from;
    private final String messagingServiceSid;
    private final String baseUrl;

    TwilioOtpSender(@Value("${app.sms.twilio.account-sid}") String accountSid,
            @Value("${app.sms.twilio.auth-token:}") String authToken,
            @Value("${app.sms.twilio.from:}") String from,
            @Value("${app.sms.twilio.messaging-service-sid:}") String messagingServiceSid,
            @Value("${app.sms.twilio.base-url:https://api.twilio.com}") String baseUrl) {
        if (authToken.isBlank() || (from.isBlank() && messagingServiceSid.isBlank())) {
            throw new IllegalStateException("app.sms.twilio.account-sid is set, but app.sms.twilio.auth-token and "
                    + "one of app.sms.twilio.from / app.sms.twilio.messaging-service-sid are required too");
        }
        this.accountSid = accountSid;
        this.authToken = authToken;
        this.from = from;
        this.messagingServiceSid = messagingServiceSid;
        this.baseUrl = baseUrl;
    }

    @Override
    public void send(String e164Phone, String code) {
        Map<String, String> form = new LinkedHashMap<>();
        form.put("To", e164Phone);
        if (!messagingServiceSid.isBlank()) {
            form.put("MessagingServiceSid", messagingServiceSid);
        } else {
            form.put("From", from);
        }
        form.put("Body", "Your ZAIRO code is " + code + ". It expires in a few minutes.");

        String credentials = Base64.getEncoder()
                .encodeToString((accountSid + ":" + authToken).getBytes(StandardCharsets.UTF_8));
        HttpRequest request = HttpRequest
                .newBuilder(URI.create(baseUrl + "/2010-04-01/Accounts/" + accountSid + "/Messages.json"))
                .timeout(REQUEST_TIMEOUT)
                .header("Authorization", "Basic " + credentials)
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(encode(form)))
                .build();
        try {
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() / 100 != 2) {
                log.error("Twilio rejected SMS to=***{} status={} body={}", lastFour(e164Phone), response.statusCode(),
                        response.body());
                throw new IllegalStateException("SMS delivery failed (Twilio status " + response.statusCode() + ")");
            }
            log.info("Twilio SMS sent to=***{}", lastFour(e164Phone));
        } catch (IOException e) {
            throw new IllegalStateException("SMS delivery failed: " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("SMS delivery interrupted", e);
        }
    }

    private static String encode(Map<String, String> form) {
        return form.entrySet().stream()
                .map(e -> URLEncoder.encode(e.getKey(), StandardCharsets.UTF_8) + "="
                        + URLEncoder.encode(e.getValue(), StandardCharsets.UTF_8))
                .collect(Collectors.joining("&"));
    }

    private static String lastFour(String phone) {
        return phone.length() <= 4 ? phone : phone.substring(phone.length() - 4);
    }
}
