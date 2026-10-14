package com.zairo.factory.ads;

import com.zairo.factory.ads.AdDtos.AdminBannerResponse;
import com.zairo.factory.ads.AdDtos.BannerResponse;
import com.zairo.factory.ads.AdDtos.CreateBannerRequest;
import com.zairo.factory.ads.AdDtos.SetStatusRequest;
import com.zairo.factory.ads.AdDtos.UpdateBannerRequest;
import com.zairo.factory.city.CityRepository;
import com.zairo.factory.platformadmin.PlatformAuditLogService;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AdService {

    /** A carousel past this many cards is noise, not a carousel. */
    static final int MAX_LIVE_BANNERS = 10;

    private final AdBannerRepository repository;
    private final PlatformAuditLogService auditLogService;
    private final CityRepository cityRepository;
    private final Clock clock;

    @Autowired
    public AdService(AdBannerRepository repository, PlatformAuditLogService auditLogService,
            CityRepository cityRepository) {
        this(repository, auditLogService, cityRepository, Clock.systemUTC());
    }

    AdService(AdBannerRepository repository, PlatformAuditLogService auditLogService, CityRepository cityRepository,
            Clock clock) {
        this.repository = repository;
        this.auditLogService = auditLogService;
        this.cityRepository = cityRepository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<BannerResponse> liveBanners(String cityCode) {
        Instant now = clock.instant();
        String city = cityCode == null || cityCode.isBlank() ? null : cityCode.trim();
        List<AdBanner> live = city == null ? repository.findLiveForEveryCity(now) : repository.findLive(now, city);
        return live.stream().limit(MAX_LIVE_BANNERS).map(BannerResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<AdminBannerResponse> listAll() {
        return repository.findAllByOrderByCreatedAtDesc().stream().map(AdminBannerResponse::from).toList();
    }

    @Transactional
    public AdminBannerResponse create(UUID actorId, String actorEmail, CreateBannerRequest request) {
        AdStatus status = request.status() == null ? AdStatus.DRAFT : request.status();
        if (status != AdStatus.DRAFT && status != AdStatus.ACTIVE) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "A new banner can only start as DRAFT or ACTIVE");
        }
        requireKnownCity(request.cityCode());
        AdBanner banner = guard(() -> new AdBanner(UUID.randomUUID(), null, request.title(), request.subtitle(),
                request.imageUrl(), request.videoUrl(), request.cityCode(), request.startsAt(), request.endsAt(),
                request.sortOrder() == null ? 0 : request.sortOrder(), status, clock.instant()));
        repository.save(banner);
        auditLogService.record(actorId, actorEmail, "AD_BANNER_CREATED", "AD_BANNER", banner.getId(), null,
                status.name(), null);
        return AdminBannerResponse.from(banner);
    }

    @Transactional
    public AdminBannerResponse update(UUID actorId, String actorEmail, UUID id, UpdateBannerRequest request) {
        requireKnownCity(request.cityCode());
        AdBanner banner = find(id);
        String previous = banner.getTitle();
        guard(() -> {
            banner.update(request.title(), request.subtitle(), request.imageUrl(), request.videoUrl(),
                    request.cityCode(), request.startsAt(), request.endsAt(),
                    request.sortOrder() == null ? 0 : request.sortOrder(), clock.instant());
            return banner;
        });
        auditLogService.record(actorId, actorEmail, "AD_BANNER_UPDATED", "AD_BANNER", id, previous,
                banner.getTitle(), null);
        return AdminBannerResponse.from(banner);
    }

    @Transactional
    public AdminBannerResponse setStatus(UUID actorId, String actorEmail, UUID id, SetStatusRequest request) {
        AdBanner banner = find(id);
        AdStatus previous = banner.getStatus();
        guard(() -> {
            banner.moveTo(request.status(), request.reason(), clock.instant());
            return banner;
        });
        auditLogService.record(actorId, actorEmail, "AD_BANNER_STATUS_CHANGED", "AD_BANNER", id, previous.name(),
                banner.getStatus().name(), request.reason());
        return AdminBannerResponse.from(banner);
    }

    @Transactional
    public void delete(UUID actorId, String actorEmail, UUID id) {
        AdBanner banner = find(id);
        repository.delete(banner);
        auditLogService.record(actorId, actorEmail, "AD_BANNER_DELETED", "AD_BANNER", id, banner.getTitle(), null,
                null);
    }

    private void requireKnownCity(String cityCode) {
        if (cityCode != null && !cityCode.isBlank() && cityRepository.findByCode(cityCode.trim()).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown city: " + cityCode);
        }
    }

    private AdBanner find(UUID id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Banner not found: " + id));
    }

    /** Domain rules throw plain exceptions; at the HTTP edge they are a 400 (bad input) or 409 (bad move). */
    private static <T> T guard(java.util.function.Supplier<T> action) {
        try {
            return action.get();
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, e.getMessage());
        } catch (IllegalStateException e) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, e.getMessage());
        }
    }
}
