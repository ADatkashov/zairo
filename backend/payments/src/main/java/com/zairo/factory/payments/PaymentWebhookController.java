package com.zairo.factory.payments;

import com.zairo.factory.paymentprovider.freedompay.FreedomPayWebhookVerifier;
import com.zairo.factory.paymentprovider.freedompay.FreedomPayWebhookVerifier.VerifiedWebhook;
import io.swagger.v3.oas.annotations.Hidden;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Map;
import java.util.SortedMap;
import java.util.TreeMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Freedom Pay's Result-notify delivery target — provider-specific and
 * isolated from every other endpoint in this codebase: form-POST in
 * ({@code pg_*} fields, not JSON), XML out (not the platform's usual JSON
 * error shape), no auth header (Freedom Pay authenticates via {@code
 * pg_sig}, not a bearer token) and never routed through {@code
 * platform-api}'s normal API surface. See ADR-0006's Webhook Architecture.
 *
 * <p><b>The response XML is not signed</b> — Freedom Pay's documented
 * response-signing requirements for Result-notify specifically (as opposed
 * to the outbound requests {@code FreedomPayProvider} signs) aren't
 * confirmed by any documentation this integration could access. TODO
 * (freedompay): confirm whether an unsigned {@code pg_status=ok} response is
 * actually sufficient to stop Freedom Pay's retries in production, or if the
 * response itself needs a {@code pg_sig} too — see ADR-0006's Open
 * Questions.
 *
 * <p>Every outcome this controller understands (bad signature, unknown
 * payment, amount mismatch, already-processed duplicate) acks {@code
 * pg_status=ok} — retrying any of those wouldn't change the outcome, so
 * acking avoids Freedom Pay hammering this endpoint for two hours over
 * something that will never resolve. Only a genuinely unexpected failure
 * (e.g. the database is unreachable) is left to surface as an HTTP 500,
 * which <i>should</i> be retried.
 */
@RestController
@Hidden
class PaymentWebhookController {

    private static final Logger log = LoggerFactory.getLogger(PaymentWebhookController.class);
    private static final String XML_HEADER = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>";

    private final FreedomPayWebhookVerifier verifier;
    private final PaymentWebhookProcessor processor;

    PaymentWebhookController(FreedomPayWebhookVerifier verifier, PaymentWebhookProcessor processor) {
        this.verifier = verifier;
        this.processor = processor;
    }

    @PostMapping(value = "/webhooks/payments/freedompay", produces = MediaType.APPLICATION_XML_VALUE)
    ResponseEntity<String> handle(@RequestParam Map<String, String> fields) {
        VerifiedWebhook webhook = verifier.verify(fields);
        PaymentWebhookProcessor.Result result = processor.process(webhook, payloadHash(fields));
        log.info("Freedom Pay webhook handled: outcome={} message={}", result.outcome(), result.message());
        return ResponseEntity.ok(XML_HEADER + "<response><pg_status>ok</pg_status></response>");
    }

    /** Audit-only fingerprint of the raw delivery — see PaymentWebhookEvent's doc comment; never used for dedup logic. */
    private static String payloadHash(Map<String, String> fields) {
        SortedMap<String, String> sorted = new TreeMap<>(fields);
        StringBuilder canonical = new StringBuilder();
        sorted.forEach((key, value) -> canonical.append(key).append('=').append(value).append('&'));
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(canonical.toString().getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                hex.append(Character.forDigit((b >> 4) & 0xF, 16));
                hex.append(Character.forDigit(b & 0xF, 16));
            }
            return hex.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }
}
