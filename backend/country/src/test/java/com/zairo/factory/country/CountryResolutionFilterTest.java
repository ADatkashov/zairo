package com.zairo.factory.country;

import static org.junit.jupiter.api.Assertions.assertEquals;

import jakarta.servlet.ServletException;
import java.io.IOException;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class CountryResolutionFilterTest {

    private final CountryResolutionFilter filter = new CountryResolutionFilter();

    @Test
    void resolvesToThePlatformDefaultWhenNoHeaderIsSent() throws ServletException, IOException {
        MockHttpServletRequest request = new MockHttpServletRequest();

        filter.doFilter(request, new MockHttpServletResponse(), new MockFilterChain());

        assertEquals("KZ", CountryContext.currentCountryCode(request));
    }

    @Test
    void resolvesToTheExplicitHeaderWhenPresent() throws ServletException, IOException {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader(CountryResolutionFilter.HEADER, "uz");

        filter.doFilter(request, new MockHttpServletResponse(), new MockFilterChain());

        // Normalized to uppercase regardless of how the client sent it.
        assertEquals("UZ", CountryContext.currentCountryCode(request));
    }

    @Test
    void blankHeaderFallsBackToTheDefaultInsteadOfResolvingToNothing() throws ServletException, IOException {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader(CountryResolutionFilter.HEADER, "   ");

        filter.doFilter(request, new MockHttpServletResponse(), new MockFilterChain());

        assertEquals("KZ", CountryContext.currentCountryCode(request));
    }

    @Test
    void currentCountryCodeFallsBackToTheDefaultIfTheFilterNeverRan() {
        // Defensive path — CountryResolutionFilter always runs in the real
        // app, but a test or a future code path might read CountryContext
        // before it does.
        MockHttpServletRequest request = new MockHttpServletRequest();

        assertEquals("KZ", CountryContext.currentCountryCode(request));
    }
}
