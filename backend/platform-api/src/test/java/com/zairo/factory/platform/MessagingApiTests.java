package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/** Against a real Postgres (Testcontainers) — basic 1:1 text chat between a customer and a business. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class MessagingApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void customerAndBusinessCanMessageEachOtherButNobodyElseCanReadOrReplyOnEitherSide() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "chat-customer-" + runId + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate, "chat-other-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "chat-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "chat-other-owner-" + runId + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Chat Salon " + runId, "beauty");
        UUID providerId = UUID.fromString(restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());

        // No token at all -> 401.
        ResponseEntity<Map> unauthenticated = restTemplate.postForEntity(
                "/api/v1/providers/" + providerId + "/messages", Map.of("body", "Hi"), Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // Customer starts the conversation.
        ResponseEntity<Map> firstMessage = restTemplate.exchange("/api/v1/providers/" + providerId + "/messages",
                HttpMethod.POST, new HttpEntity<>(Map.of("body", "Is Saturday still open?"),
                        TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(firstMessage.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID conversationId = UUID.fromString(firstMessage.getBody().get("conversationId").toString());

        // A second message from the same customer continues the SAME thread, not a new one.
        restTemplate.exchange("/api/v1/providers/" + providerId + "/messages", HttpMethod.POST,
                new HttpEntity<>(Map.of("body", "Also, do you take walk-ins?"),
                        TestAuth.authHeaders(customer.accessToken())), Map.class);

        // The customer can read their own thread straight from the providerId.
        ResponseEntity<List> ownThread = restTemplate.exchange("/api/v1/providers/" + providerId + "/messages",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), List.class);
        assertThat(ownThread.getBody()).hasSize(2);

        // A different business owner can't reply on this conversation.
        ResponseEntity<Map> forbiddenReply = restTemplate.exchange(
                "/api/v1/conversations/" + conversationId + "/messages", HttpMethod.POST,
                new HttpEntity<>(Map.of("body", "sneaky"), TestAuth.authHeaders(otherOwner.accessToken())),
                Map.class);
        assertThat(forbiddenReply.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // A different customer can't read this conversation either.
        ResponseEntity<Map> forbiddenRead = restTemplate.exchange(
                "/api/v1/conversations/" + conversationId + "/messages", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())), Map.class);
        assertThat(forbiddenRead.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // The real business owner can reply.
        ResponseEntity<Map> ownerReply = restTemplate.exchange(
                "/api/v1/conversations/" + conversationId + "/messages", HttpMethod.POST,
                new HttpEntity<>(Map.of("body", "Yes, see you then!"), TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        assertThat(ownerReply.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        // The full thread now has 3 messages, oldest first.
        ResponseEntity<List> fullThread = restTemplate.exchange(
                "/api/v1/conversations/" + conversationId + "/messages", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), List.class);
        assertThat(fullThread.getBody()).hasSize(3);
        Map<?, ?> lastMessage = (Map<?, ?>) fullThread.getBody().get(2);
        assertThat(lastMessage.get("body")).isEqualTo("Yes, see you then!");

        // Shows up in both inboxes.
        ResponseEntity<List> customerInbox = restTemplate.exchange("/api/v1/conversations/mine", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), List.class);
        assertThat(customerInbox.getBody()).anySatisfy(entry -> {
            Map<?, ?> conversation = (Map<?, ?>) entry;
            assertThat(conversation.get("id")).isEqualTo(conversationId.toString());
        });

        ResponseEntity<List> businessInbox = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/conversations", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), List.class);
        assertThat(businessInbox.getBody()).hasSize(1);

        // A different owner can't read this business's inbox.
        ResponseEntity<Map> forbiddenInbox = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/conversations", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(forbiddenInbox.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void messagingAnUnknownProviderReturns404AndABlankMessageIsRejected() {
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "chat-notfound-" + UUID.randomUUID() + "@example.com");

        ResponseEntity<Map> notFound = restTemplate.exchange(
                "/api/v1/providers/" + UUID.randomUUID() + "/messages", HttpMethod.POST,
                new HttpEntity<>(Map.of("body", "hello?"), TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(notFound.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        Registered owner = TestAuth.registerOwner(restTemplate,
                "chat-blank-owner-" + UUID.randomUUID() + "@example.com");
        UUID providerId = UUID.fromString(restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(new CreateProviderRequest(owner.userId(), "Blank Test Salon", "beauty"),
                        TestAuth.authHeaders(owner.accessToken())),
                Map.class).getBody().get("id").toString());

        ResponseEntity<Map> blankBody = restTemplate.exchange("/api/v1/providers/" + providerId + "/messages",
                HttpMethod.POST, new HttpEntity<>(Map.of("body", "   "), TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(blankBody.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }
}
