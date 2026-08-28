package com.zairo.factory.paymentprovider.freedompay;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * No official Freedom Pay worked example was findable during this
 * integration's research (see ADR-0006) — these tests instead pin down the
 * algorithm's own documented shape (scriptName;sorted-values;secretKey, MD5
 * hex) against hand-computed expectations, so a future accidental change to
 * field ordering or joining is caught even without a provider-supplied
 * fixture.
 */
class FreedomPaySignatureTest {

    @Test
    void sortsFieldsByKeyNotInsertionOrderBeforeSigning() {
        Map<String, String> inOneOrder = new LinkedHashMap<>();
        inOneOrder.put("pg_amount", "10.00");
        inOneOrder.put("pg_merchant_id", "m1");

        Map<String, String> inAnotherOrder = new LinkedHashMap<>();
        inAnotherOrder.put("pg_merchant_id", "m1");
        inAnotherOrder.put("pg_amount", "10.00");

        assertEquals(FreedomPaySignature.compute("init_payment.php", inOneOrder, "secret"),
                FreedomPaySignature.compute("init_payment.php", inAnotherOrder, "secret"));
    }

    @Test
    void computeMatchesItsOwnHandExpansion() {
        Map<String, String> fields = new LinkedHashMap<>();
        fields.put("pg_amount", "10.00");
        fields.put("pg_merchant_id", "m1");

        // scriptName;10.00;m1;secret — values in ascending key order (pg_amount < pg_merchant_id).
        String expected = md5Hex("init_payment.php;10.00;m1;secret");
        assertEquals(expected, FreedomPaySignature.compute("init_payment.php", fields, "secret"));
    }

    @Test
    void matchesReturnsTrueForTheSignatureItJustComputedAndFalseForAnythingElse() {
        Map<String, String> fields = Map.of("pg_payment_id", "123", "pg_result", "1");
        String signature = FreedomPaySignature.compute("result.php", fields, "s3cret");

        assertTrue(FreedomPaySignature.matches("result.php", fields, "s3cret", signature));
        assertFalse(FreedomPaySignature.matches("result.php", fields, "wrong-secret", signature));
        assertFalse(FreedomPaySignature.matches("other.php", fields, "s3cret", signature));
    }

    @Test
    void aDifferentSecretKeyProducesADifferentSignature() {
        Map<String, String> fields = Map.of("pg_payment_id", "123");
        assertFalse(FreedomPaySignature.compute("result.php", fields, "secret-a")
                .equals(FreedomPaySignature.compute("result.php", fields, "secret-b")));
    }

    private static String md5Hex(String input) {
        try {
            java.security.MessageDigest digest = java.security.MessageDigest.getInstance("MD5");
            byte[] hash = digest.digest(input.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                hex.append(Character.forDigit((b >> 4) & 0xF, 16));
                hex.append(Character.forDigit(b & 0xF, 16));
            }
            return hex.toString();
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
