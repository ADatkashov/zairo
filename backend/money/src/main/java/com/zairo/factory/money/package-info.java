/**
 * A shared {@link com.zairo.factory.money.Money} value type, replacing the
 * independent {@code BigDecimal amount + String currency} column pairs that
 * previously lived separately in {@code services}, {@code booking}, and
 * {@code payments}. Foundational: everything else may depend on this,
 * this depends on nothing else.
 *
 * <p>Deliberately not built here (no real consumer yet — see the "Factory
 * Master Architecture" design document, section 4): exchange rates,
 * multi-currency conversion, historical rates, a general currency/tax
 * engine. This module is exactly one type: an amount that knows its own
 * currency and refuses to be constructed with an invalid one.
 */
package com.zairo.factory.money;
