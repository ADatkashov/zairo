package com.zairo.factory.ads;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zairo.factory.ads.AdDtos.AdminBannerResponse;
import com.zairo.factory.ads.AdDtos.BannerResponse;
import com.zairo.factory.ads.AdDtos.CreateBannerRequest;
import com.zairo.factory.ads.AdDtos.SetStatusRequest;
import com.zairo.factory.ads.AdDtos.UpdateBannerRequest;
import com.zairo.factory.city.City;
import com.zairo.factory.city.CityRepository;
import com.zairo.factory.platformadmin.PlatformAuditLogService;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.IntStream;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

class AdServiceTest {

    private static final Instant NOW = Instant.parse("2026-10-14T10:00:00Z");
    private static final Instant START = NOW.minusSeconds(60);
    private static final Instant END = NOW.plusSeconds(3600);
    private static final UUID ACTOR = UUID.randomUUID();

    private final AdBannerRepository repository = mock(AdBannerRepository.class);
    private final PlatformAuditLogService audit = mock(PlatformAuditLogService.class);
    private final CityRepository cities = mock(CityRepository.class);
    private final AdService service = new AdService(repository, audit, cities, Clock.fixed(NOW, ZoneOffset.UTC));

    {
        when(cities.findByCode("almaty")).thenReturn(Optional.of(mock(City.class)));
    }

    private static AdBanner banner(AdStatus status) {
        return new AdBanner(UUID.randomUUID(), null, "Title", null, "https://cdn.example/c.jpg", null, null, START,
                END, 0, status, NOW);
    }

    private static CreateBannerRequest create(AdStatus status, String image) {
        return new CreateBannerRequest("Title", null, image, "https://video.example/v", "almaty", START, END, null,
                status);
    }

    private static ResponseStatusException status(Throwable t) {
        return (ResponseStatusException) t;
    }

    @Test
    void liveBannersWithACityAskForThatCityPlusEveryCity() {
        AdBanner b = new AdBanner(UUID.randomUUID(), UUID.randomUUID(), "Sponsored", "Sub",
                "https://cdn.example/c.jpg", "https://video.example/v", "almaty", START, END, 0, AdStatus.ACTIVE, NOW);
        when(repository.findLive(NOW, "almaty")).thenReturn(List.of(b));

        List<BannerResponse> result = service.liveBanners(" almaty ");

        assertThat(result).hasSize(1);
        assertThat(result.get(0).title()).isEqualTo("Sponsored");
        assertThat(result.get(0).videoUrl()).isEqualTo("https://video.example/v");
        assertThat(result.get(0).sponsored()).isTrue();
    }

    @Test
    void liveBannersWithoutACityOnlyReturnEveryCityBanners() {
        when(repository.findLiveForEveryCity(NOW)).thenReturn(List.of(banner(AdStatus.ACTIVE)));

        assertThat(service.liveBanners(null)).hasSize(1);
        assertThat(service.liveBanners("  ")).hasSize(1);
        verify(repository, never()).findLive(any(), any());
    }

    @Test
    void aPlatformBannerIsNotMarkedSponsored() {
        when(repository.findLiveForEveryCity(NOW)).thenReturn(List.of(banner(AdStatus.ACTIVE)));

        assertThat(service.liveBanners(null).get(0).sponsored()).isFalse();
    }

    @Test
    void theCarouselIsCappedAtTenBanners() {
        when(repository.findLiveForEveryCity(NOW)).thenReturn(
                IntStream.range(0, 15).mapToObj(i -> banner(AdStatus.ACTIVE)).toList());

        assertThat(service.liveBanners(null)).hasSize(AdService.MAX_LIVE_BANNERS);
    }

    @Test
    void createStartsAsDraftAndIsAuditLogged() {
        AdminBannerResponse created = service.create(ACTOR, "a@x", create(null, "https://cdn.example/c.jpg"));

        assertThat(created.status()).isEqualTo(AdStatus.DRAFT);
        assertThat(created.sortOrder()).isZero();
        assertThat(created.providerId()).isNull();
        verify(repository).save(any(AdBanner.class));
        verify(audit).record(eq(ACTOR), eq("a@x"), eq("AD_BANNER_CREATED"), eq("AD_BANNER"), eq(created.id()), eq(null),
                eq("DRAFT"), eq(null));
    }

    @Test
    void createWithAnUnknownCityIsABadRequestAndSavesNothing() {
        CreateBannerRequest request = new CreateBannerRequest("Title", null, "https://cdn.example/c.jpg", null,
                "no-such-city", START, END, null, null);

        assertThatThrownBy(() -> service.create(ACTOR, "a@x", request))
                .satisfies(t -> assertThat(status(t).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST))
                .hasMessageContaining("no-such-city");
        verify(repository, never()).save(any());
    }

    @Test
    void updateWithAnUnknownCityIsABadRequest() {
        AdBanner existing = banner(AdStatus.DRAFT);
        when(repository.findById(existing.getId())).thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> service.update(ACTOR, "a@x", existing.getId(), new UpdateBannerRequest("T", null,
                "https://cdn.example/c.jpg", null, "no-such-city", START, END, null)))
                .satisfies(t -> assertThat(status(t).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST));
        assertThat(existing.getCityCode()).isNull();
    }

    @Test
    void createCanStartActive() {
        assertThat(service.create(ACTOR, "a@x", create(AdStatus.ACTIVE, "https://cdn.example/c.jpg")).status())
                .isEqualTo(AdStatus.ACTIVE);
    }

    @Test
    void createRefusesAnyOtherStartingStatus() {
        for (AdStatus bad : new AdStatus[] {AdStatus.PENDING_REVIEW, AdStatus.PAUSED, AdStatus.REJECTED}) {
            assertThatThrownBy(() -> service.create(ACTOR, "a@x", create(bad, "https://cdn.example/c.jpg")))
                    .satisfies(t -> assertThat(status(t).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST));
        }
        verify(repository, never()).save(any());
    }

    @Test
    void createWithAnInvalidUrlIsABadRequestAndSavesNothing() {
        assertThatThrownBy(() -> service.create(ACTOR, "a@x", create(null, "http://cdn.example/c.jpg")))
                .satisfies(t -> assertThat(status(t).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST));
        verify(repository, never()).save(any());
        verify(audit, never()).record(any(), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void updateChangesTheBannerAndLogsTheOldTitle() {
        AdBanner existing = banner(AdStatus.DRAFT);
        when(repository.findById(existing.getId())).thenReturn(Optional.of(existing));

        AdminBannerResponse updated = service.update(ACTOR, "a@x", existing.getId(), new UpdateBannerRequest("New",
                null, "https://cdn.example/n.jpg", null, null, START, END, 4));

        assertThat(updated.title()).isEqualTo("New");
        assertThat(updated.sortOrder()).isEqualTo(4);
        verify(audit).record(ACTOR, "a@x", "AD_BANNER_UPDATED", "AD_BANNER", existing.getId(), "Title", "New", null);
    }

    @Test
    void updateWithAnInvalidWindowIsABadRequest() {
        AdBanner existing = banner(AdStatus.DRAFT);
        when(repository.findById(existing.getId())).thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> service.update(ACTOR, "a@x", existing.getId(), new UpdateBannerRequest("New", null,
                "https://cdn.example/n.jpg", null, null, END, START, null)))
                .satisfies(t -> assertThat(status(t).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST));
    }

    @Test
    void setStatusMovesTheBannerAndLogsBeforeAndAfter() {
        AdBanner existing = banner(AdStatus.PENDING_REVIEW);
        when(repository.findById(existing.getId())).thenReturn(Optional.of(existing));

        AdminBannerResponse result = service.setStatus(ACTOR, "a@x", existing.getId(),
                new SetStatusRequest(AdStatus.REJECTED, "Misleading"));

        assertThat(result.status()).isEqualTo(AdStatus.REJECTED);
        assertThat(result.rejectionReason()).isEqualTo("Misleading");
        verify(audit).record(ACTOR, "a@x", "AD_BANNER_STATUS_CHANGED", "AD_BANNER", existing.getId(),
                "PENDING_REVIEW", "REJECTED", "Misleading");
    }

    @Test
    void rejectingWithoutAReasonIsABadRequest() {
        AdBanner existing = banner(AdStatus.PENDING_REVIEW);
        when(repository.findById(existing.getId())).thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> service.setStatus(ACTOR, "a@x", existing.getId(),
                new SetStatusRequest(AdStatus.REJECTED, null)))
                .satisfies(t -> assertThat(status(t).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST));
    }

    @Test
    void aMoveTheLifecycleForbidsIsAConflict() {
        AdBanner existing = banner(AdStatus.DRAFT);
        when(repository.findById(existing.getId())).thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> service.setStatus(ACTOR, "a@x", existing.getId(),
                new SetStatusRequest(AdStatus.PAUSED, null)))
                .satisfies(t -> assertThat(status(t).getStatusCode()).isEqualTo(HttpStatus.CONFLICT));
        verify(audit, never()).record(any(), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void deleteRemovesTheBannerAndLogsIt() {
        AdBanner existing = banner(AdStatus.PAUSED);
        when(repository.findById(existing.getId())).thenReturn(Optional.of(existing));

        service.delete(ACTOR, "a@x", existing.getId());

        verify(repository).delete(existing);
        verify(audit).record(ACTOR, "a@x", "AD_BANNER_DELETED", "AD_BANNER", existing.getId(), "Title", null, null);
    }

    @Test
    void anUnknownBannerIsANotFound() {
        UUID id = UUID.randomUUID();
        when(repository.findById(id)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(ACTOR, "a@x", id))
                .satisfies(t -> assertThat(status(t).getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND));
        assertThatThrownBy(() -> service.update(ACTOR, "a@x", id,
                new UpdateBannerRequest("T", null, "https://cdn.example/c.jpg", null, null, START, END, null)))
                .satisfies(t -> assertThat(status(t).getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND));
        assertThatThrownBy(() -> service.setStatus(ACTOR, "a@x", id, new SetStatusRequest(AdStatus.ACTIVE, null)))
                .satisfies(t -> assertThat(status(t).getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND));
    }

    @Test
    void listAllReturnsEveryStatusNewestFirstFromTheRepository() {
        when(repository.findAllByOrderByCreatedAtDesc())
                .thenReturn(List.of(banner(AdStatus.ACTIVE), banner(AdStatus.REJECTED)));

        assertThat(service.listAll()).extracting(AdminBannerResponse::status)
                .containsExactly(AdStatus.ACTIVE, AdStatus.REJECTED);
    }
}
