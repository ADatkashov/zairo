package com.zairo.factory.smartfill;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.EnumSet;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Plain unit tests of the two Smart Fill aggregates' state changes. */
class SmartFillLifecycleTest {

    private static final Instant T0 = Instant.parse("2026-10-12T10:00:00Z");
    private static final Instant T1 = Instant.parse("2026-10-12T10:15:00Z");
    private static final Instant T2 = Instant.parse("2026-10-12T10:30:00Z");

    private static SmartFillCampaign campaign() {
        return new SmartFillCampaign(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                UUID.randomUUID(), UUID.randomUUID(), T2, T2.plusSeconds(3600), new BigDecimal("8000"), "KZT", T0);
    }

    private static CandidateOffer offer() {
        return new CandidateOffer(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), 55, 1,
                0, EnumSet.of(ScoringFactor.FOLLOWS_PROVIDER, ScoringFactor.CATEGORY_INTEREST), T0);
    }

    @Test
    void newCampaignIsActiveAtStageZero() {
        SmartFillCampaign c = campaign();

        assertThat(c.getStatus()).isEqualTo(SmartFillCampaignStatus.CREATED);
        assertThat(c.getCurrentStage()).isZero();
        assertThat(c.isActive()).isTrue();
        assertThat(c.getPriceAmount()).isEqualByComparingTo("8000");
        assertThat(c.getPriceCurrency()).isEqualTo("KZT");
    }

    @Test
    void sendingAStageMovesToNotifyingAndSchedulesTheNextOne() {
        SmartFillCampaign c = campaign();

        c.markStageSent(2, T1);

        assertThat(c.getStatus()).isEqualTo(SmartFillCampaignStatus.NOTIFYING);
        assertThat(c.getCurrentStage()).isEqualTo(2);
        assertThat(c.getNextStageAt()).isEqualTo(T1);
        assertThat(c.isActive()).isTrue();
    }

    @Test
    void bookingEndsTheCampaignAndRemembersTheRecoveredBooking() {
        SmartFillCampaign c = campaign();
        c.markStageSent(1, T1);
        UUID booking = UUID.randomUUID();

        c.markBooked(booking, T2);

        assertThat(c.getStatus()).isEqualTo(SmartFillCampaignStatus.BOOKED);
        assertThat(c.getRecoveredBookingId()).isEqualTo(booking);
        assertThat(c.getNextStageAt()).isNull();
        assertThat(c.getCompletedAt()).isEqualTo(T2);
        assertThat(c.isActive()).isFalse();
    }

    @Test
    void expiredAndCancelledCampaignsAreFinishedAndNotActive() {
        SmartFillCampaign expired = campaign();
        expired.markExpired(T2);
        SmartFillCampaign cancelled = campaign();
        cancelled.markCancelled(T2);

        assertThat(expired.getStatus()).isEqualTo(SmartFillCampaignStatus.EXPIRED);
        assertThat(expired.isActive()).isFalse();
        assertThat(expired.getCompletedAt()).isEqualTo(T2);
        assertThat(cancelled.getStatus()).isEqualTo(SmartFillCampaignStatus.CANCELLED);
        assertThat(cancelled.isActive()).isFalse();
        assertThat(cancelled.getNextStageAt()).isNull();
    }

    @Test
    void pausingStopsTheScheduleAndResumingSetsANewOne() {
        SmartFillCampaign c = campaign();
        c.markStageSent(1, T1);

        c.markPaused();
        assertThat(c.getStatus()).isEqualTo(SmartFillCampaignStatus.PAUSED);
        assertThat(c.getNextStageAt()).isNull();
        assertThat(c.isActive()).isFalse();

        c.markResumed(T2);
        assertThat(c.getStatus()).isEqualTo(SmartFillCampaignStatus.NOTIFYING);
        assertThat(c.getNextStageAt()).isEqualTo(T2);
    }

    @Test
    void searchingIsAnActiveState() {
        SmartFillCampaign c = campaign();

        c.markSearching();

        assertThat(c.getStatus()).isEqualTo(SmartFillCampaignStatus.SEARCHING);
        assertThat(c.isActive()).isTrue();
    }

    @Test
    void newOfferIsPendingAndStoresItsFactorsAsCsv() {
        CandidateOffer o = offer();

        assertThat(o.getStatus()).isEqualTo(CandidateOfferStatus.PENDING);
        assertThat(o.getScore()).isEqualTo(55);
        assertThat(o.getMatchedFactors().split(","))
                .containsExactlyInAnyOrder("FOLLOWS_PROVIDER", "CATEGORY_INTEREST");
    }

    @Test
    void offerWalksPendingNotifiedViewedAccepted() {
        CandidateOffer o = offer();
        UUID booking = UUID.randomUUID();

        o.markNotified(T1);
        assertThat(o.getStatus()).isEqualTo(CandidateOfferStatus.NOTIFIED);
        assertThat(o.getNotifiedAt()).isEqualTo(T1);

        o.markViewed();
        assertThat(o.getStatus()).isEqualTo(CandidateOfferStatus.VIEWED);

        o.markAccepted(booking, T2);
        assertThat(o.getStatus()).isEqualTo(CandidateOfferStatus.ACCEPTED);
        assertThat(o.getBookingId()).isEqualTo(booking);
        assertThat(o.getRespondedAt()).isEqualTo(T2);
    }

    @Test
    void viewingAnOfferThatWasNeverNotifiedChangesNothing() {
        CandidateOffer o = offer();

        o.markViewed();

        assertThat(o.getStatus()).isEqualTo(CandidateOfferStatus.PENDING);
    }

    @Test
    void openOffersCanBeCancelledOrExpired() {
        for (CandidateOfferStatus start : new CandidateOfferStatus[] {CandidateOfferStatus.PENDING,
                CandidateOfferStatus.NOTIFIED, CandidateOfferStatus.VIEWED}) {
            CandidateOffer cancelled = offerIn(start);
            cancelled.markCancelled();
            assertThat(cancelled.getStatus()).isEqualTo(CandidateOfferStatus.CANCELLED);

            CandidateOffer expired = offerIn(start);
            expired.markExpired();
            assertThat(expired.getStatus()).isEqualTo(CandidateOfferStatus.EXPIRED);
        }
    }

    @Test
    void anAcceptedOfferIsNeverCancelledOrExpiredLater() {
        CandidateOffer o = offer();
        o.markAccepted(UUID.randomUUID(), T1);

        o.markCancelled();
        o.markExpired();

        assertThat(o.getStatus()).isEqualTo(CandidateOfferStatus.ACCEPTED);
    }

    private static CandidateOffer offerIn(CandidateOfferStatus status) {
        CandidateOffer o = offer();
        if (status != CandidateOfferStatus.PENDING) {
            o.markNotified(T1);
        }
        if (status == CandidateOfferStatus.VIEWED) {
            o.markViewed();
        }
        return o;
    }
}
