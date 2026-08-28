package com.zairo.factory.paymentprovider.freedompay;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Map;
import java.util.SortedMap;
import java.util.TreeMap;

/**
 * Freedom Pay's {@code pg_sig} algorithm (docs.freedompay.kz — see
 * ADR-0006's Webhook Architecture / Security sections): MD5 hex digest of
 * {@code scriptName;value1;value2;...;secretKey}, where the values are
 * every {@code pg_*} field <b>except {@code pg_sig} itself</b>, taken in
 * ascending alphabetical order of their field name (not the order they
 * appear in the request/response) — {@code pg_salt} is included as just
 * another field in that sort, not treated specially beyond that.
 *
 * <p>MD5 is Freedom Pay's real, documented choice, not a weaker algorithm
 * Factory substituted — see ADR-0006's Security section for why this isn't
 * "fixed" to something stronger: doing so would simply produce a signature
 * Freedom Pay's own servers don't compute, breaking every real request.
 *
 * <p>Pure function, no I/O — exists as its own class specifically so it's
 * unit-testable against Freedom Pay's own documented worked example without
 * a network call or a Spring context.
 */
final class FreedomPaySignature {

    private FreedomPaySignature() {
    }

    /**
     * @param scriptName the endpoint name Freedom Pay includes as the first
     *                    signed value — confidently {@code "init_payment.php"}
     *                    for outbound payment creation (documented) and
     *                    {@code "revoke.php"} for outbound refunds
     *                    (documented endpoint name, see {@code
     *                    FreedomPayProvider#refund}); for the <em>inbound</em>
     *                    Result-notify webhook this is whatever script name
     *                    Freedom Pay's merchant panel is configured to call
     *                    — see {@code FreedomPayProperties} and the webhook
     *                    verifier's own TODO for why that value isn't
     *                    hardcoded here.
     * @param fields      every {@code pg_*} field from the request/response
     *                    EXCEPT {@code pg_sig} — caller's responsibility to
     *                    exclude it, this method doesn't filter it out
     *                    defensively so an accidental extra field is a loud
     *                    signature mismatch, not a silently-ignored bug.
     */
    static String compute(String scriptName, Map<String, String> fields, String secretKey) {
        SortedMap<String, String> sorted = new TreeMap<>(fields);
        StringBuilder toSign = new StringBuilder(scriptName);
        for (String value : sorted.values()) {
            toSign.append(';').append(value == null ? "" : value);
        }
        toSign.append(';').append(secretKey);
        return md5Hex(toSign.toString());
    }

    /** Constant-time-ish comparison isn't meaningful for MD5 hex strings of fixed length — plain equals is fine here. */
    static boolean matches(String scriptName, Map<String, String> fields, String secretKey, String expectedSig) {
        return compute(scriptName, fields, secretKey).equalsIgnoreCase(expectedSig);
    }

    private static String md5Hex(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("MD5");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                hex.append(Character.forDigit((b >> 4) & 0xF, 16));
                hex.append(Character.forDigit(b & 0xF, 16));
            }
            return hex.toString();
        } catch (NoSuchAlgorithmException e) {
            // MD5 is a mandatory JDK algorithm (every conforming JVM ships
            // it) — this can't actually happen, but the checked exception
            // still has to go somewhere.
            throw new IllegalStateException("MD5 not available", e);
        }
    }
}
