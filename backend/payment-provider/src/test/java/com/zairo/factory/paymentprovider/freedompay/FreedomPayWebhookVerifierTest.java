package com.zairo.factory.paymentprovider.freedompay;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.zairo.factory.paymentprovider.freedompay.FreedomPayWebhookVerifier.VerifiedWebhook;
import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

class FreedomPayWebhookVerifierTest {

    private static final String SECRET_KEY = "s3cret";
    private static final String SCRIPT_NAME = "result.php";

    private final FreedomPayWebhookVerifier verifier = new FreedomPayWebhookVerifier(
            new FreedomPayProperties("https://api.freedompay.example", "merchant-1", SECRET_KEY, SCRIPT_NAME));

    @Test
    void aCorrectlySignedSuccessfulPaymentParsesCleanly() {
        Map<String, String> fields = fields("pay-1", "booking-payment:pay-1", "25.00", "USD", "1");

        VerifiedWebhook result = verifier.verify(fields);

        assertTrue(result.signatureValid());
        assertEquals("pay-1", result.providerPaymentId());
        assertEquals("booking-payment:pay-1", result.orderId());
        assertTrue(result.paymentSucceeded());
        assertEquals(new BigDecimal("25.00"), result.amount());
        assertEquals("USD", result.currency());
    }

    @Test
    void pgResultZeroMeansNotSucceeded() {
        Map<String, String> fields = fields("pay-2", "booking-payment:pay-2", "25.00", "USD", "0");
        assertFalse(verifier.verify(fields).paymentSucceeded());
    }

    @Test
    void aTamperedFieldAfterSigningInvalidatesTheSignature() {
        Map<String, String> fields = fields("pay-3", "booking-payment:pay-3", "25.00", "USD", "1");
        fields.put("pg_amount", "999.00"); // tampered after the pg_sig above was computed for 25.00

        VerifiedWebhook result = verifier.verify(fields);
        assertFalse(result.signatureValid());
    }

    @Test
    void aMissingSignatureIsRejectedWithoutComputingAnything() {
        Map<String, String> fields = new LinkedHashMap<>();
        fields.put("pg_payment_id", "pay-4");
        fields.put("pg_result", "1");

        VerifiedWebhook result = verifier.verify(fields);
        assertFalse(result.signatureValid());
        assertEquals("missing pg_sig", result.invalidReason());
    }

    private Map<String, String> fields(String paymentId, String orderId, String amount, String currency,
            String pgResult) {
        Map<String, String> fields = new LinkedHashMap<>();
        fields.put("pg_payment_id", paymentId);
        fields.put("pg_order_id", orderId);
        fields.put("pg_amount", amount);
        fields.put("pg_currency", currency);
        fields.put("pg_result", pgResult);
        fields.put("pg_sig", FreedomPaySignature.compute(SCRIPT_NAME, fields, SECRET_KEY));
        return fields;
    }
}
