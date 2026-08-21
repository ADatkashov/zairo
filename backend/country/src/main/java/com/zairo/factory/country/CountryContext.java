package com.zairo.factory.country;

import jakarta.servlet.http.HttpServletRequest;

/**
 * Cross-module entry point for "which country is this request for" — reads
 * what {@link CountryResolutionFilter} already populated, the same pattern
 * as auth's {@code CurrentUser} reading {@code JwtAuthFilter}'s attributes.
 * Business services should call this instead of ever reading
 * {@code X-Country} themselves — that keeps the resolution algorithm in
 * exactly one place, so it can grow (Phase C) without every call site
 * changing.
 */
public final class CountryContext {

    /**
     * The whole platform is Kazakhstan-only today, so this is a fine
     * literal default — it stops being one once a second ACTIVE country
     * exists and "no signal at all" needs a real decision instead of an
     * assumption.
     */
    static final String DEFAULT_COUNTRY_CODE = "KZ";

    private CountryContext() {
    }

    /** Always returns a value — CountryResolutionFilter guarantees the attribute is set. */
    public static String currentCountryCode(HttpServletRequest request) {
        Object value = request.getAttribute(CountryResolutionFilter.COUNTRY_CODE_ATTRIBUTE);
        return value instanceof String code ? code : DEFAULT_COUNTRY_CODE;
    }
}
