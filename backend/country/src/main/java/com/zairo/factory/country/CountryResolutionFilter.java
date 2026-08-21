package com.zairo.factory.country;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Resolves which country this request is for, the same "populate a request
 * attribute, let a static helper read it" shape as auth's JwtAuthFilter /
 * CurrentUser. Phase A's resolution order is deliberately short — an
 * explicit header, else the platform default — because there's no
 * user-profile country field yet (Phase C adds "authenticated user's
 * profile country" as a step between the two once that exists); nothing
 * downstream should assume this order is final.
 *
 * <p>Unlike JwtAuthFilter, this never leaves the attribute unset: every
 * request resolves to *some* country, so {@link CountryContext} never has
 * a "missing" case to throw on.
 */
@Component
class CountryResolutionFilter extends OncePerRequestFilter {

    static final String COUNTRY_CODE_ATTRIBUTE = "country.code";
    static final String HEADER = "X-Country";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String header = request.getHeader(HEADER);
        String resolved = (header == null || header.isBlank())
                ? CountryContext.DEFAULT_COUNTRY_CODE
                : header.trim().toUpperCase();
        request.setAttribute(COUNTRY_CODE_ATTRIBUTE, resolved);
        chain.doFilter(request, response);
    }
}
