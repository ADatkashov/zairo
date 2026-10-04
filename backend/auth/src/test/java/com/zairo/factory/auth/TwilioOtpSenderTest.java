package com.zairo.factory.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class TwilioOtpSenderTest {

    private HttpServer server;
    private final AtomicReference<String> path = new AtomicReference<>();
    private final AtomicReference<String> auth = new AtomicReference<>();
    private final AtomicReference<String> body = new AtomicReference<>();
    private volatile int status = 201;

    @BeforeEach
    void startServer() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", exchange -> {
            path.set(exchange.getRequestURI().getPath());
            auth.set(exchange.getRequestHeaders().getFirst("Authorization"));
            body.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] out = "{\"sid\":\"SM1\"}".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status, out.length);
            exchange.getResponseBody().write(out);
            exchange.close();
        });
        server.start();
    }

    @AfterEach
    void stopServer() {
        server.stop(0);
    }

    private String baseUrl() {
        return "http://127.0.0.1:" + server.getAddress().getPort();
    }

    @Test
    void postsFormWithBasicAuthAndFromNumber() {
        new TwilioOtpSender("AC123", "secret", "+15005550006", "", baseUrl()).send("+77001234567", "123456");

        assertThat(path.get()).isEqualTo("/2010-04-01/Accounts/AC123/Messages.json");
        assertThat(auth.get())
                .isEqualTo("Basic " + Base64.getEncoder().encodeToString("AC123:secret".getBytes(StandardCharsets.UTF_8)));
        assertThat(body.get()).contains("To=%2B77001234567").contains("From=%2B15005550006").contains("123456");
    }

    @Test
    void messagingServiceWinsOverFrom() {
        new TwilioOtpSender("AC123", "secret", "+15005550006", "MG999", baseUrl()).send("+77001234567", "123456");

        assertThat(body.get()).contains("MessagingServiceSid=MG999").doesNotContain("From=");
    }

    @Test
    void nonSuccessStatusFailsTheSend() {
        status = 400;
        TwilioOtpSender sender = new TwilioOtpSender("AC123", "secret", "+15005550006", "", baseUrl());

        assertThatThrownBy(() -> sender.send("+77001234567", "123456"))
                .isInstanceOf(OtpTemporarilyUnavailableException.class);
    }

    @Test
    void incompleteConfigurationIsRejectedAtStartup() {
        assertThatThrownBy(() -> new TwilioOtpSender("AC123", "", "+1", "", baseUrl()))
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new TwilioOtpSender("AC123", "secret", "", "", baseUrl()))
                .isInstanceOf(IllegalStateException.class);
    }
}
