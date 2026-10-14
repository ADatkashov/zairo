package com.zairo.factory.invitations;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class StaffInvitationTest {

    private static final Instant T0 = Instant.parse("2026-10-12T10:00:00Z");

    private static StaffInvitation invitation() {
        return new StaffInvitation(UUID.randomUUID(), UUID.randomUUID(), "+77001234567", InvitationKind.MASTER, T0);
    }

    @Test
    void newInvitationIsPendingAndUnresolved() {
        StaffInvitation i = invitation();

        assertThat(i.getStatus()).isEqualTo(InvitationStatus.PENDING);
        assertThat(i.getPhone()).isEqualTo("+77001234567");
        assertThat(i.getCreatedAt()).isEqualTo(T0);
        assertThat(i.getFailureReason()).isNull();
    }

    @Test
    void acceptingRecordsTheUser() {
        StaffInvitation i = invitation();
        UUID user = UUID.randomUUID();

        i.accept(user);

        assertThat(i.getStatus()).isEqualTo(InvitationStatus.ACCEPTED);
    }

    @Test
    void cancellingMarksItCancelled() {
        StaffInvitation i = invitation();

        i.cancel();

        assertThat(i.getStatus()).isEqualTo(InvitationStatus.CANCELLED);
    }

    @Test
    void failingKeepsTheReason() {
        StaffInvitation i = invitation();

        i.fail("plan limit reached");

        assertThat(i.getStatus()).isEqualTo(InvitationStatus.FAILED);
        assertThat(i.getFailureReason()).isEqualTo("plan limit reached");
    }

    @Test
    void aVeryLongFailureReasonIsTruncatedToTheColumnSize() {
        StaffInvitation i = invitation();

        i.fail("x".repeat(1000));

        assertThat(i.getFailureReason()).hasSize(255);
    }

    @Test
    void aNullFailureReasonIsAllowed() {
        StaffInvitation i = invitation();

        i.fail(null);

        assertThat(i.getStatus()).isEqualTo(InvitationStatus.FAILED);
        assertThat(i.getFailureReason()).isNull();
    }
}
