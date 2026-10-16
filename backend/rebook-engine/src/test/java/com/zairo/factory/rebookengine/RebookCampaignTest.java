package com.zairo.factory.rebookengine;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class RebookCampaignTest {

    private static final Instant T0 = Instant.parse("2026-10-01T10:00:00Z");
    private static final Instant T1 = Instant.parse("2026-10-12T10:00:00Z");

    private static RebookCampaign campaign() {
        return new RebookCampaign(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                UUID.randomUUID(), T0, 28, T0.plusSeconds(28 * 86400L), T0.plusSeconds(40 * 86400L),
                new BigDecimal("6000"), "KZT", T0);
    }

    @Test
    void newCampaignIsCreatedAndActive() {
        RebookCampaign c = campaign();

        assertThat(c.getStatus()).isEqualTo(RebookCampaignStatus.CREATED);
        assertThat(c.isActive()).isTrue();
        assertThat(c.getAverageIntervalDays()).isEqualTo(28);
        assertThat(c.getPriceAmount()).isEqualByComparingTo("6000");
        assertThat(c.getPriceCurrency()).isEqualTo("KZT");
        assertThat(c.getCompletedAt()).isNull();
    }

    @Test
    void anOfferedCampaignIsStillActive() {
        RebookCampaign c = campaign();

        c.markOffered(T1);

        assertThat(c.getStatus()).isEqualTo(RebookCampaignStatus.OFFERED);
        assertThat(c.isActive()).isTrue();
    }

    @Test
    void bookingEndsTheCampaignWithTheRecoveredBooking() {
        RebookCampaign c = campaign();
        UUID booking = UUID.randomUUID();
        c.markOffered(T1);

        c.markBooked(booking, T1);

        assertThat(c.getStatus()).isEqualTo(RebookCampaignStatus.BOOKED);
        assertThat(c.getRecoveredBookingId()).isEqualTo(booking);
        assertThat(c.getCompletedAt()).isEqualTo(T1);
        assertThat(c.isActive()).isFalse();
    }

    @Test
    void expiredAndCancelledCampaignsAreNotActive() {
        RebookCampaign expired = campaign();
        expired.markExpired(T1);
        RebookCampaign cancelled = campaign();
        cancelled.markCancelled(T1);

        assertThat(expired.getStatus()).isEqualTo(RebookCampaignStatus.EXPIRED);
        assertThat(expired.isActive()).isFalse();
        assertThat(expired.getCompletedAt()).isEqualTo(T1);
        assertThat(cancelled.getStatus()).isEqualTo(RebookCampaignStatus.CANCELLED);
        assertThat(cancelled.isActive()).isFalse();
    }
}
