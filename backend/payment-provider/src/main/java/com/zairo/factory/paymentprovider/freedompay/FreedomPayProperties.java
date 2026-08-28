package com.zairo.factory.paymentprovider.freedompay;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * {@code payment.freedompay.*} — see application.yml for the actual
 * {@code ${ENV_VAR:default}} values. Every field here is a real, documented
 * Freedom Pay concept (docs.freedompay.kz — see ADR-0006's Booking Payment
 * Architecture and Security sections for the field-by-field source), not a
 * guessed/generic payment-gateway shape:
 *
 * <ul>
 *   <li>{@code apiUrl} — base URL for the classic {@code pg_*} API family
 *   (form-POST, XML responses) — <b>not</b> the newer JWT-based
 *   {@code /v5/merchant} surface, which is a structurally different API
 *   Factory doesn't use (ADR-0006, "Decision"). No confirmed separate
 *   sandbox host exists (ADR-0006, Open Questions #2) — staging and
 *   production both set this explicitly; there is no hardcoded default
 *   pointing at either, on purpose.</li>
 *   <li>{@code merchantId} — {@code pg_merchant_id} on every request.</li>
 *   <li>{@code secretKey} — used for <b>both</b> signing outbound requests
 *   and verifying inbound webhook signatures (Freedom Pay doesn't document
 *   a separate webhook secret — see ADR-0006's Security section for why
 *   this makes the one value maximally sensitive).</li>
 *   <li>{@code resultNotifyScriptName} — <b>unconfirmed, see
 *   ADR-0006 Open Questions #6.</b> The script name Freedom Pay signs its
 *   Result-notify webhook with is whatever it's configured (merchant panel)
 *   to call — not something Factory's code can derive on its own. Defaults
 *   to a best guess (see application.yml); {@link FreedomPayWebhookVerifier}
 *   uses this value as-is, so correcting it once confirmed is a config
 *   change, not a code change.</li>
 * </ul>
 *
 * Deliberately does <b>not</b> have a {@code webhookSecret} field the way a
 * generic payment-config template might suggest — that field doesn't
 * correspond to anything Freedom Pay's real API actually has (confirmed via
 * docs.freedompay.kz, not assumed); adding it would be exactly the kind of
 * invented-field the implementation task this was built from explicitly
 * warned against.
 */
@ConfigurationProperties(prefix = "payment.freedompay")
public record FreedomPayProperties(String apiUrl, String merchantId, String secretKey, String resultNotifyScriptName) {
}
