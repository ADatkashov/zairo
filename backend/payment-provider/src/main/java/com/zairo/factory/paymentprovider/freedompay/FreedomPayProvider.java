package com.zairo.factory.paymentprovider.freedompay;

import com.zairo.factory.paymentprovider.PaymentProvider;
import com.zairo.factory.paymentprovider.PaymentProviderName;
import com.zairo.factory.paymentprovider.UnsupportedRecurringChargeException;
import java.math.BigDecimal;
import java.security.SecureRandom;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Real Freedom Pay integration — classic {@code pg_*} form-POST/XML API
 * (docs.freedompay.kz), hosted-checkout redirect model: card data goes to
 * Freedom Pay's own page, never to Factory (no PCI scope on our side). See
 * {@code docs/adr/0006-payment-provider-freedompay.md} for the full design.
 *
 * <p><b>This call's return value is not the final word on payment success</b>
 * — {@link #createPayment}/{@link #createRecurringPayment} return {@link
 * PaymentProvider.InitiationStatus#PENDING} once Freedom Pay accepts the
 * request; the actual outcome is confirmed later by their Result-notify
 * webhook (see {@code platform-api}'s webhook controller), independently of
 * whether the customer's browser ever returns to {@code successUrl}/{@code
 * failureUrl} — those are UX-only, not a trust boundary (ADR-0006, Booking
 * Payment Architecture: "frontend redirect — не источник истины").
 *
 * <p><b>{@link #chargeRecurring} is not implemented</b> — Freedom Pay's real
 * request shape for charging a previously-saved recurring profile isn't
 * confirmed by any public documentation this integration could access (see
 * ADR-0006, Open Questions #1). Calling it throws {@link
 * UnsupportedRecurringChargeException} rather than guessing a shape that
 * might silently double-charge or silently no-op against the real API —
 * {@code SubscriptionRenewalService} already treats any {@code
 * RuntimeException} from a charge attempt as "this renewal failed, enter
 * PAST_DUE", so this fails safely into the exact handling this codebase
 * already has, not a new failure mode.
 *
 * <p><b>{@link #refund} does not send fiscal receipt line items</b> — Freedom
 * Pay's refund docs reference {@code pg_receipt_positions[...]} fields
 * (Kazakhstan ККМ/fiscal requirements) that Factory has no data model for
 * today (ADR-0006, Open Questions #4, Refund Architecture). If the real API
 * rejects a refund for missing receipt data, that surfaces as an honest
 * {@link PaymentProvider.RefundResult#succeeded()} {@code false} — not
 * fabricated receipt data.
 */
@Component
@ConditionalOnProperty(name = "payment.provider", havingValue = "freedompay")
public class FreedomPayProvider implements PaymentProvider {

    private static final Logger log = LoggerFactory.getLogger(FreedomPayProvider.class);
    private static final DateTimeFormatter ISO_DATE = DateTimeFormatter.ISO_LOCAL_DATE;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final FreedomPayHttpClient httpClient;
    private final FreedomPayProperties properties;

    public FreedomPayProvider(FreedomPayProperties properties) {
        if (properties.apiUrl() == null || properties.apiUrl().isBlank()) {
            // Fail loudly at boot, not on the first real payment attempt —
            // same "don't silently run on an empty/wrong value" reasoning
            // as the env-var externalization work this ADR builds on.
            throw new IllegalStateException("payment.provider=freedompay but payment.freedompay.api-url is not "
                    + "set — see application.yml / FREEDOMPAY_API_URL");
        }
        this.properties = properties;
        this.httpClient = new FreedomPayHttpClient(properties.apiUrl());
    }

    @Override
    public PaymentInitiation createPayment(UUID paymentId, BigDecimal amount, String currency, String description,
            String successUrl, String failureUrl) {
        Map<String, String> fields = baseFields(paymentId, amount, currency, description, successUrl, failureUrl);
        return initiate("init_payment.php", fields, paymentId);
    }

    @Override
    public PaymentInitiation createRecurringPayment(UUID paymentId, BigDecimal amount, String currency,
            String description, String successUrl, String failureUrl) {
        Map<String, String> fields = baseFields(paymentId, amount, currency, description, successUrl, failureUrl);
        // pg_recurring_start/pg_recurring_lifetime are real, documented
        // field names (ADR-0006) — their exact value semantics (lifetime
        // unit, whether "start" must be today) aren't spelled out anywhere
        // this integration could confirm. Best-effort: today's date,
        // 365-day lifetime. TODO(freedompay): confirm both against a real
        // sandbox response before relying on the resulting recurring
        // profile for a production charge.
        fields.put("pg_recurring_start", LocalDate.now().format(ISO_DATE));
        fields.put("pg_recurring_lifetime", "365");
        return initiate("init_payment.php", fields, paymentId);
    }

    @Override
    public ChargeResult chargeRecurring(String recurringProfileId, UUID paymentId, BigDecimal amount,
            String currency) {
        log.warn("chargeRecurring called (paymentId={}, provider=FREEDOMPAY) but is not implemented — "
                + "see ADR-0006 Open Questions #1", paymentId);
        throw new UnsupportedRecurringChargeException(
                "Freedom Pay recurring-profile charge is not confirmed by public documentation — "
                        + "see docs/adr/0006-payment-provider-freedompay.md, Open Questions #1. "
                        + "recurringProfileId=" + recurringProfileId);
    }

    @Override
    public PaymentStatusResult getPaymentStatus(UUID paymentId, String providerPaymentId) {
        Map<String, String> fields = new HashMap<>();
        fields.put("pg_merchant_id", properties.merchantId());
        fields.put("pg_payment_id", providerPaymentId);
        fields.put("pg_salt", salt());
        sign("get_status3.php", fields);

        Map<String, String> response = call("get_status3.php", fields, paymentId, "getPaymentStatus");
        boolean ok = "ok".equalsIgnoreCase(response.get("pg_status"));
        InitiationStatus status = !ok ? InitiationStatus.FAILED : mapResultToStatus(response.get("pg_result"));
        return new PaymentStatusResult(status, response.get("pg_payment_id"));
    }

    @Override
    public RefundResult refund(UUID paymentId, String providerPaymentId, BigDecimal amount) {
        Map<String, String> fields = new HashMap<>();
        fields.put("pg_merchant_id", properties.merchantId());
        fields.put("pg_payment_id", providerPaymentId);
        if (amount != null) {
            fields.put("pg_refund_amount", amount.toPlainString());
        }
        fields.put("pg_salt", salt());
        // TODO(freedompay): endpoint name is "revoke.php" per the one
        // documented "Refund payment" page this integration could access
        // (docs.freedompay.kz) — a second "/g2g/refund" endpoint also
        // exists in the wider docs tree with an unclear relationship to
        // this one (ADR-0006, Open Questions #3). Using the confirmed one.
        String scriptName = "revoke.php";
        sign(scriptName, fields);

        Map<String, String> response;
        try {
            response = call(scriptName, fields, paymentId, "refund");
        } catch (FreedomPayHttpException e) {
            return new RefundResult(false, e.getMessage());
        }
        boolean ok = "ok".equalsIgnoreCase(response.get("pg_status"));
        return new RefundResult(ok, ok ? null : errorMessage(response));
    }

    private Map<String, String> baseFields(UUID paymentId, BigDecimal amount, String currency, String description,
            String successUrl, String failureUrl) {
        Map<String, String> fields = new HashMap<>();
        fields.put("pg_merchant_id", properties.merchantId());
        fields.put("pg_amount", amount.toPlainString());
        fields.put("pg_currency", currency);
        fields.put("pg_description", description);
        // Format documented in ADR-0006's Webhook Architecture — lets the
        // webhook handler route to the right domain object without an
        // ambiguous lookup across two tables sharing the UUID space.
        fields.put("pg_order_id", "booking-payment:" + paymentId);
        fields.put("pg_success_url", successUrl);
        fields.put("pg_failure_url", failureUrl);
        // Real, documented field (ADR-0006) — forwarded as our own
        // idempotency key so a retried createPayment call (e.g. after a
        // client-side timeout) doesn't necessarily mint a second charge on
        // Freedom Pay's side. Exact retry semantics aren't confirmed
        // (Open Questions #5) — Factory doesn't rely on this alone, see
        // PaymentsService.createPayment's own idempotency guard.
        fields.put("pg_idempotency_key", paymentId.toString());
        fields.put("pg_salt", salt());
        return fields;
    }

    private PaymentInitiation initiate(String scriptName, Map<String, String> fields, UUID paymentId) {
        sign(scriptName, fields);
        Map<String, String> response;
        try {
            response = call(scriptName, fields, paymentId, "createPayment");
        } catch (FreedomPayHttpException e) {
            return new PaymentInitiation(null, null, null, InitiationStatus.FAILED, e.getMessage());
        }

        boolean ok = "ok".equalsIgnoreCase(response.get("pg_status"));
        if (!ok) {
            return new PaymentInitiation(response.get("pg_payment_id"), null, null, InitiationStatus.FAILED,
                    errorMessage(response));
        }
        return new PaymentInitiation(response.get("pg_payment_id"), response.get("pg_redirect_url"),
                response.get("pg_recurring_profile_id"), InitiationStatus.PENDING, null);
    }

    private Map<String, String> call(String scriptName, Map<String, String> fields, UUID paymentId,
            String operation) {
        long startedAt = System.nanoTime();
        try {
            Map<String, String> response = httpClient.post(scriptName, fields);
            log.info("Freedom Pay {} paymentId={} provider=FREEDOMPAY status={} durationMs={}", operation, paymentId,
                    response.get("pg_status"), (System.nanoTime() - startedAt) / 1_000_000);
            return response;
        } catch (FreedomPayHttpException e) {
            log.warn("Freedom Pay {} paymentId={} provider=FREEDOMPAY errorCode={} durationMs={}", operation,
                    paymentId, e.getClass().getSimpleName(), (System.nanoTime() - startedAt) / 1_000_000);
            throw e;
        }
    }

    private void sign(String scriptName, Map<String, String> fields) {
        fields.put("pg_sig", FreedomPaySignature.compute(scriptName, fields, properties.secretKey()));
    }

    private static InitiationStatus mapResultToStatus(String pgResult) {
        // pg_result: 1 = success, 0 = failure, 2 = incomplete (docs.freedompay.kz).
        return switch (pgResult == null ? "" : pgResult) {
            case "1" -> InitiationStatus.SUCCEEDED;
            case "0" -> InitiationStatus.FAILED;
            default -> InitiationStatus.PENDING;
        };
    }

    private static String errorMessage(Map<String, String> response) {
        String description = response.get("pg_error_description");
        if (description != null && !description.isBlank()) {
            return description;
        }
        return "Freedom Pay returned pg_status=" + response.get("pg_status");
    }

    private static String salt() {
        return Long.toUnsignedString(RANDOM.nextLong());
    }

    static PaymentProviderName name() {
        return PaymentProviderName.FREEDOMPAY;
    }
}
