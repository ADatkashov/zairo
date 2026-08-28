/**
 * The {@link com.zairo.factory.paymentprovider.PaymentProvider} port and its
 * two implementations: {@link com.zairo.factory.paymentprovider.MockPaymentProvider}
 * (local/test) and {@link com.zairo.factory.paymentprovider.freedompay.FreedomPayProvider}
 * (staging/production) — selected by {@code payment.provider} config, see
 * application.yml. Extracted from {@code payments} once {@code
 * subscriptions} needed the same port for recurring charges — see this
 * module's build.gradle.kts for why that would otherwise have created a
 * Gradle module cycle. Provider-specific mechanics (Freedom Pay's {@code
 * pg_*} field family, MD5 signing, XML parsing) live entirely under the
 * {@code freedompay} subpackage — see {@code docs/adr/0006-payment-provider-freedompay.md}.
 */
package com.zairo.factory.paymentprovider;
