package com.zairo.factory.paymentprovider.freedompay;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * Verifies and parses a Freedom Pay Result-notify webhook delivery into a
 * provider-agnostic shape ({@code platform-api}'s webhook controller never
 * sees a raw {@code pg_*} field) — see ADR-0006's Webhook Architecture.
 *
 * <p><b>{@code scriptName} for signature verification is a real open
 * question</b> (ADR-0006, Open Questions #6): the value Freedom Pay signs
 * with is the script name it's configured (in the merchant panel) to call
 * for Result notify — not necessarily something Factory's code can derive
 * on its own. {@link FreedomPayProperties#resultNotifyScriptName()} exists
 * specifically so this is one config value to correct once confirmed,
 * not a code change — see that field's own doc comment. <b>TODO(freedompay):
 * confirm the exact script name Freedom Pay signs Result-notify callbacks
 * with, against the real merchant panel configuration, before relying on
 * signature verification in production.</b>
 */
@Component
public class FreedomPayWebhookVerifier {

    private final FreedomPayProperties properties;

    public FreedomPayWebhookVerifier(FreedomPayProperties properties) {
        this.properties = properties;
    }

    /**
     * @param fields every {@code pg_*} field from the callback's POST body,
     *               including {@code pg_sig} (this method removes it before
     *               computing the expected signature).
     */
    public VerifiedWebhook verify(Map<String, String> fields) {
        String receivedSig = fields.get("pg_sig");
        if (receivedSig == null) {
            return VerifiedWebhook.invalid("missing pg_sig");
        }
        Map<String, String> withoutSig = new LinkedHashMap<>(fields);
        withoutSig.remove("pg_sig");

        boolean signatureValid = FreedomPaySignature.matches(properties.resultNotifyScriptName(), withoutSig,
                properties.secretKey(), receivedSig);
        if (!signatureValid) {
            return VerifiedWebhook.invalid("signature mismatch");
        }

        String orderId = fields.get("pg_order_id");
        String providerPaymentId = fields.get("pg_payment_id");
        if (orderId == null || providerPaymentId == null) {
            return VerifiedWebhook.invalid("missing pg_order_id/pg_payment_id");
        }

        // pg_result: 1 = success, 0 = failure, 2 = incomplete (docs.freedompay.kz).
        String pgResult = fields.getOrDefault("pg_result", "");
        boolean succeeded = "1".equals(pgResult);

        BigDecimal amount = parseAmount(fields.get("pg_amount"));
        String currency = fields.get("pg_currency");

        // No unique per-delivery event id exists in this API — pg_payment_id
        // doubles as the dedup key (up to 4 retries over 2h reuse the same
        // value). See ADR-0006's Webhook Architecture for why this shapes
        // payment_webhook_event's (provider, event_id) constraint the way
        // it does.
        return new VerifiedWebhook(true, null, providerPaymentId, orderId, succeeded, amount, currency);
    }

    private static BigDecimal parseAmount(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return new BigDecimal(raw);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    public record VerifiedWebhook(boolean signatureValid, String invalidReason, String providerPaymentId,
            String orderId, boolean paymentSucceeded, BigDecimal amount, String currency) {

        static VerifiedWebhook invalid(String reason) {
            return new VerifiedWebhook(false, reason, null, null, false, null, null);
        }
    }
}
