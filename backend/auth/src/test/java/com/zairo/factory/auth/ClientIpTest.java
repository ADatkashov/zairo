package com.zairo.factory.auth;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.servlet.http.HttpServletRequest;
import java.lang.reflect.Proxy;
import org.junit.jupiter.api.Test;

class ClientIpTest {

    private static HttpServletRequest request(String forwardedFor, String remoteAddr) {
        return (HttpServletRequest) Proxy.newProxyInstance(getClass0(), new Class<?>[] {HttpServletRequest.class},
                (proxy, method, args) -> switch (method.getName()) {
                    case "getHeader" -> "X-Forwarded-For".equals(args[0]) ? forwardedFor : null;
                    case "getRemoteAddr" -> remoteAddr;
                    default -> null;
                });
    }

    private static ClassLoader getClass0() {
        return ClientIpTest.class.getClassLoader();
    }

    @Test
    void takesTheEntryTheTrustedProxyAppendedNotTheSpoofableLeftmostOne() {
        // A client sending its own "X-Forwarded-For: 6.6.6.6" is appended to by the real proxy.
        assertThat(ClientIp.of(request("6.6.6.6, 203.0.113.9", "10.0.0.1"), 1)).isEqualTo("203.0.113.9");
        assertThat(ClientIp.of(request("203.0.113.9, 172.16.0.5", "10.0.0.1"), 2)).isEqualTo("203.0.113.9");
    }

    @Test
    void fallsBackToTheSocketAddressWhenTheHeaderIsAbsentOrIgnored() {
        assertThat(ClientIp.of(request(null, "198.51.100.7"), 1)).isEqualTo("198.51.100.7");
        assertThat(ClientIp.of(request("6.6.6.6", "198.51.100.7"), 0)).isEqualTo("198.51.100.7");
        assertThat(ClientIp.of(request("1.1.1.1", "198.51.100.7"), 3)).isEqualTo("198.51.100.7");
    }
}
