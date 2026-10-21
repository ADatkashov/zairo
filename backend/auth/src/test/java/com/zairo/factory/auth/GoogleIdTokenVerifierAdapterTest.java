package com.zairo.factory.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Google's tokeninfo endpoint is replaced by a local server, so no real Google call is made. */
class GoogleIdTokenVerifierAdapterTest {

    private HttpServer server;
    private final AtomicInteger calls = new AtomicInteger();
    private String tokenInfoUrl;

    @BeforeEach
    void setUp() throws Exception {
        String body = "{\"iss\":\"accounts.google.com\",\"aud\":\"client-1\",\"sub\":\"g-1\",\"email\":\"a@example.com\","
                + "\"email_verified\":\"true\",\"exp\":\"" + (Instant.now().getEpochSecond() + 600) + "\"}";
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/tokeninfo", exchange -> {
            calls.incrementAndGet();
            byte[] out = body.getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, out.length);
            exchange.getResponseBody().write(out);
            exchange.close();
        });
        server.start();
        tokenInfoUrl = "http://127.0.0.1:" + server.getAddress().getPort() + "/tokeninfo";
    }

    @AfterEach
    void tearDown() {
        server.stop(0);
    }

    @Test
    void acceptsAValidTokenWhenSwitchedOn() {
        var adapter = new GoogleIdTokenVerifierAdapter("client-1", tokenInfoUrl, true);

        assertThat(adapter.verify("some-token")).hasValueSatisfying(identity -> {
            assertThat(identity.subject()).isEqualTo("g-1");
            assertThat(identity.emailVerified()).isTrue();
        });
    }

    @Test
    void aSwitchedOffAdapterRejectsEveryTokenWithoutCallingGoogle() {
        // Blank client ids would normally mean "accept any audience"; switched off must still fail closed.
        var adapter = new GoogleIdTokenVerifierAdapter("", tokenInfoUrl, false);

        assertThat(adapter.verify("some-token")).isEmpty();
        assertThat(calls).hasValue(0);
    }

    @Test
    void rejectsAWrongAudienceBlankAndNull() {
        var adapter = new GoogleIdTokenVerifierAdapter("another-client", tokenInfoUrl, true);

        assertThat(adapter.verify("some-token")).isEmpty();
        assertThat(adapter.verify("")).isEmpty();
        assertThat(adapter.verify(null)).isEmpty();
    }
}
