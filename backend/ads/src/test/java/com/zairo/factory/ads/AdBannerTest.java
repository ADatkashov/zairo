package com.zairo.factory.ads;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class AdBannerTest {

    private static final Instant NOW = Instant.parse("2026-10-14T10:00:00Z");
    private static final Instant START = NOW.minusSeconds(3600);
    private static final Instant END = NOW.plusSeconds(3600);

    private static AdBanner banner(AdStatus status, String city) {
        return new AdBanner(UUID.randomUUID(), null, "Digital Bridge", "Forum", "https://cdn.example/cover.jpg",
                "https://video.example/watch", city, START, END, 0, status, NOW);
    }

    @Test
    void anActiveBannerInsideItsWindowIsLive() {
        assertThat(banner(AdStatus.ACTIVE, null).isLiveAt(NOW, "almaty")).isTrue();
    }

    @Test
    void onlyActiveBannersAreLive() {
        for (AdStatus status : AdStatus.values()) {
            assertThat(banner(status, null).isLiveAt(NOW, null)).isEqualTo(status == AdStatus.ACTIVE);
        }
    }

    @Test
    void theWindowIsStartInclusiveEndExclusive() {
        AdBanner b = banner(AdStatus.ACTIVE, null);

        assertThat(b.isLiveAt(START.minusSeconds(1), null)).isFalse();
        assertThat(b.isLiveAt(START, null)).isTrue();
        assertThat(b.isLiveAt(END.minusSeconds(1), null)).isTrue();
        assertThat(b.isLiveAt(END, null)).isFalse();
    }

    @Test
    void aCityBannerIsOnlyLiveInItsCityButAnEveryCityBannerIsLiveEverywhere() {
        AdBanner almaty = banner(AdStatus.ACTIVE, "almaty");
        AdBanner everywhere = banner(AdStatus.ACTIVE, null);

        assertThat(almaty.isLiveAt(NOW, "almaty")).isTrue();
        assertThat(almaty.isLiveAt(NOW, "astana")).isFalse();
        assertThat(everywhere.isLiveAt(NOW, "astana")).isTrue();
    }

    @Test
    void blankOptionalFieldsBecomeNull() {
        AdBanner b = new AdBanner(UUID.randomUUID(), null, "  Title  ", " ", "https://cdn.example/c.jpg", "  ", " ",
                START, END, 3, AdStatus.DRAFT, NOW);

        assertThat(b.getTitle()).isEqualTo("Title");
        assertThat(b.getSubtitle()).isNull();
        assertThat(b.getVideoUrl()).isNull();
        assertThat(b.getCityCode()).isNull();
        assertThat(b.getSortOrder()).isEqualTo(3);
    }

    @Test
    void urlsMustBeHttps() {
        for (String bad : new String[] {"http://cdn.example/x.jpg", "javascript:alert(1)", "file:///etc/passwd",
                "//cdn.example/x.jpg", "https://", "not a url"}) {
            assertThatThrownBy(() -> new AdBanner(UUID.randomUUID(), null, "T", null, bad, null, null, START, END,
                    0, AdStatus.DRAFT, NOW)).as(bad).isInstanceOf(IllegalArgumentException.class);
        }
        assertThatThrownBy(() -> new AdBanner(UUID.randomUUID(), null, "T", null, "https://cdn.example/x.jpg",
                "http://video.example/v", null, START, END, 0, AdStatus.DRAFT, NOW))
                .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("videoUrl");
    }

    @Test
    void aTitleAndAPositiveWindowAreRequired() {
        assertThatThrownBy(() -> new AdBanner(UUID.randomUUID(), null, " ", null, "https://cdn.example/x.jpg", null,
                null, START, END, 0, AdStatus.DRAFT, NOW)).hasMessageContaining("title");
        assertThatThrownBy(() -> new AdBanner(UUID.randomUUID(), null, "T", null, "https://cdn.example/x.jpg", null,
                null, END, START, 0, AdStatus.DRAFT, NOW)).hasMessageContaining("endsAt");
        assertThatThrownBy(() -> new AdBanner(UUID.randomUUID(), null, "T", null, "https://cdn.example/x.jpg", null,
                null, START, START, 0, AdStatus.DRAFT, NOW)).hasMessageContaining("endsAt");
    }

    @Test
    void updateReplacesContentButKeepsStatus() {
        AdBanner b = banner(AdStatus.ACTIVE, null);
        Instant later = NOW.plusSeconds(60);

        b.update("New", "Sub", "https://cdn.example/n.jpg", null, "astana", START, END.plusSeconds(60), 5, later);

        assertThat(b.getTitle()).isEqualTo("New");
        assertThat(b.getVideoUrl()).isNull();
        assertThat(b.getCityCode()).isEqualTo("astana");
        assertThat(b.getStatus()).isEqualTo(AdStatus.ACTIVE);
        assertThat(b.getUpdatedAt()).isEqualTo(later);
        assertThat(b.getCreatedAt()).isEqualTo(NOW);
    }

    @Test
    void updateRejectsABadWindowAndLeavesTheBannerUntouched() {
        AdBanner b = banner(AdStatus.ACTIVE, null);

        assertThatThrownBy(() -> b.update("New", null, "https://cdn.example/n.jpg", null, null, END, START, 0, NOW))
                .isInstanceOf(IllegalArgumentException.class);
        assertThat(b.getTitle()).isEqualTo("Digital Bridge");
    }

    @Test
    void theHappyPathLifecycle() {
        AdBanner b = banner(AdStatus.DRAFT, null);

        b.moveTo(AdStatus.PENDING_REVIEW, null, NOW);
        b.moveTo(AdStatus.ACTIVE, null, NOW);
        b.moveTo(AdStatus.PAUSED, null, NOW);
        b.moveTo(AdStatus.ACTIVE, null, NOW);

        assertThat(b.getStatus()).isEqualTo(AdStatus.ACTIVE);
    }

    @Test
    void rejectingNeedsAReasonThatIsKeptUntilTheBannerMovesOn() {
        AdBanner b = banner(AdStatus.PENDING_REVIEW, null);

        assertThatThrownBy(() -> b.moveTo(AdStatus.REJECTED, " ", NOW)).hasMessageContaining("reason");
        assertThat(b.getStatus()).isEqualTo(AdStatus.PENDING_REVIEW);

        b.moveTo(AdStatus.REJECTED, "Misleading claim", NOW);
        assertThat(b.getRejectionReason()).isEqualTo("Misleading claim");

        b.moveTo(AdStatus.PENDING_REVIEW, null, NOW);
        assertThat(b.getRejectionReason()).isNull();
    }

    @Test
    void aLiveBannerCanBePulledByRejectingIt() {
        AdBanner b = banner(AdStatus.ACTIVE, null);

        b.moveTo(AdStatus.REJECTED, "Complaint", NOW);

        assertThat(b.getStatus()).isEqualTo(AdStatus.REJECTED);
        assertThat(b.isLiveAt(NOW, null)).isFalse();
    }

    @Test
    void movesTheLifecycleDoesNotAllowAreRefused() {
        assertThatThrownBy(() -> banner(AdStatus.DRAFT, null).moveTo(AdStatus.PAUSED, null, NOW))
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> banner(AdStatus.ACTIVE, null).moveTo(AdStatus.DRAFT, null, NOW))
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> banner(AdStatus.REJECTED, null).moveTo(AdStatus.ACTIVE, null, NOW))
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> banner(AdStatus.PENDING_REVIEW, null).moveTo(AdStatus.PAUSED, null, NOW))
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> banner(AdStatus.DRAFT, null).moveTo(AdStatus.REJECTED, "x", NOW))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void movingToTheCurrentStatusIsANoOp() {
        AdBanner b = banner(AdStatus.ACTIVE, null);
        Instant later = NOW.plusSeconds(5);

        b.moveTo(AdStatus.ACTIVE, null, later);

        assertThat(b.getUpdatedAt()).isEqualTo(NOW);
    }

    @Test
    void aRejectedBannerCanGoBackToDraftAndAPausedOneToo() {
        AdBanner rejected = banner(AdStatus.REJECTED, null);
        AdBanner paused = banner(AdStatus.PAUSED, null);

        rejected.moveTo(AdStatus.DRAFT, null, NOW);
        paused.moveTo(AdStatus.DRAFT, null, NOW);

        assertThat(rejected.getStatus()).isEqualTo(AdStatus.DRAFT);
        assertThat(paused.getStatus()).isEqualTo(AdStatus.DRAFT);
    }
}
