package com.zairo.factory.ads;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.net.URI;
import java.net.URISyntaxException;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "ad_banner")
public class AdBanner {

    @Id
    private UUID id;

    /** The business that bought the placement; null for a banner the platform runs itself. */
    @Column(name = "provider_id")
    private UUID providerId;

    @Column(nullable = false)
    private String title;

    private String subtitle;

    @Column(name = "image_url", nullable = false)
    private String imageUrl;

    /** https link to the video on an external host; null = the banner opens nothing. */
    @Column(name = "video_url")
    private String videoUrl;

    /** Where a tap opens inside the app when there is no video; null = nowhere. */
    @Enumerated(EnumType.STRING)
    @Column(name = "link_target", length = 20)
    private AdLinkTarget linkTarget;

    /** Null = shown in every city. */
    @Column(name = "city_code")
    private String cityCode;

    @Column(name = "starts_at", nullable = false)
    private Instant startsAt;

    @Column(name = "ends_at", nullable = false)
    private Instant endsAt;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AdStatus status;

    @Column(name = "rejection_reason")
    private String rejectionReason;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected AdBanner() {
    }

    public AdBanner(UUID id, UUID providerId, String title, String subtitle, String imageUrl, String videoUrl,
            String cityCode, Instant startsAt, Instant endsAt, int sortOrder, AdStatus status, Instant now) {
        this(id, providerId, title, subtitle, imageUrl, videoUrl, null, cityCode, startsAt, endsAt, sortOrder, status,
                now);
    }

    public AdBanner(UUID id, UUID providerId, String title, String subtitle, String imageUrl, String videoUrl,
            AdLinkTarget linkTarget, String cityCode, Instant startsAt, Instant endsAt, int sortOrder,
            AdStatus status, Instant now) {
        requireWindow(startsAt, endsAt);
        this.id = id;
        this.providerId = providerId;
        this.title = requireText(title, "title");
        this.subtitle = blankToNull(subtitle);
        this.imageUrl = requireHttps(imageUrl, "imageUrl");
        this.videoUrl = videoUrl == null || videoUrl.isBlank() ? null : requireHttps(videoUrl, "videoUrl");
        this.linkTarget = linkTarget;
        this.cityCode = blankToNull(cityCode);
        this.startsAt = startsAt;
        this.endsAt = endsAt;
        this.sortOrder = sortOrder;
        this.status = status;
        this.createdAt = now;
        this.updatedAt = now;
    }

    /** Replaces everything an editor can change; status moves only through {@link #moveTo}. */
    public void update(String title, String subtitle, String imageUrl, String videoUrl, String cityCode,
            Instant startsAt, Instant endsAt, int sortOrder, Instant now) {
        update(title, subtitle, imageUrl, videoUrl, null, cityCode, startsAt, endsAt, sortOrder, now);
    }

    public void update(String title, String subtitle, String imageUrl, String videoUrl, AdLinkTarget linkTarget,
            String cityCode, Instant startsAt, Instant endsAt, int sortOrder, Instant now) {
        requireWindow(startsAt, endsAt);
        this.linkTarget = linkTarget;
        this.title = requireText(title, "title");
        this.subtitle = blankToNull(subtitle);
        this.imageUrl = requireHttps(imageUrl, "imageUrl");
        this.videoUrl = videoUrl == null || videoUrl.isBlank() ? null : requireHttps(videoUrl, "videoUrl");
        this.cityCode = blankToNull(cityCode);
        this.startsAt = startsAt;
        this.endsAt = endsAt;
        this.sortOrder = sortOrder;
        this.updatedAt = now;
    }

    /**
     * Moves the banner to {@code target}. Anything can go to DRAFT/PAUSED/ACTIVE
     * from a state where that makes sense; REJECTED needs a reason and is only
     * reachable from PENDING_REVIEW or ACTIVE/PAUSED (a moderator pulling a
     * live banner); PENDING_REVIEW only comes from DRAFT or REJECTED (a
     * resubmission).
     *
     * @throws IllegalStateException if the move is not allowed
     * @throws IllegalArgumentException if rejecting without a reason
     */
    public void moveTo(AdStatus target, String reason, Instant now) {
        if (target == status) {
            return;
        }
        boolean allowed = switch (target) {
            case DRAFT -> status == AdStatus.REJECTED || status == AdStatus.PAUSED;
            case PENDING_REVIEW -> status == AdStatus.DRAFT || status == AdStatus.REJECTED;
            case ACTIVE -> status == AdStatus.DRAFT || status == AdStatus.PENDING_REVIEW
                    || status == AdStatus.PAUSED;
            case PAUSED -> status == AdStatus.ACTIVE;
            case REJECTED -> status == AdStatus.PENDING_REVIEW || status == AdStatus.ACTIVE
                    || status == AdStatus.PAUSED;
        };
        if (!allowed) {
            throw new IllegalStateException("A banner cannot go from " + status + " to " + target);
        }
        if (target == AdStatus.REJECTED) {
            this.rejectionReason = requireText(reason, "reason");
        } else {
            this.rejectionReason = null;
        }
        this.status = target;
        this.updatedAt = now;
    }

    /** Whether the Home carousel may show this banner at {@code now} in {@code city} (null city = no filter). */
    public boolean isLiveAt(Instant now, String city) {
        if (status != AdStatus.ACTIVE || now.isBefore(startsAt) || !now.isBefore(endsAt)) {
            return false;
        }
        return cityCode == null || city == null || cityCode.equals(city);
    }

    private static void requireWindow(Instant startsAt, Instant endsAt) {
        if (startsAt == null || endsAt == null || !endsAt.isAfter(startsAt)) {
            throw new IllegalArgumentException("endsAt must be after startsAt");
        }
    }

    private static String requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " is required");
        }
        return value.trim();
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    /**
     * Only https links: a banner's image and video are loaded by every
     * customer's app, so a {@code javascript:}/{@code file:}/plain-http URL
     * is refused here instead of being trusted by the client.
     */
    static String requireHttps(String url, String field) {
        String value = requireText(url, field);
        try {
            URI uri = new URI(value);
            if (!"https".equalsIgnoreCase(uri.getScheme()) || uri.getHost() == null) {
                throw new IllegalArgumentException(field + " must be an https URL");
            }
        } catch (URISyntaxException e) {
            throw new IllegalArgumentException(field + " must be an https URL");
        }
        return value;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public String getTitle() {
        return title;
    }

    public String getSubtitle() {
        return subtitle;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public String getVideoUrl() {
        return videoUrl;
    }

    public AdLinkTarget getLinkTarget() {
        return linkTarget;
    }

    public String getCityCode() {
        return cityCode;
    }

    public Instant getStartsAt() {
        return startsAt;
    }

    public Instant getEndsAt() {
        return endsAt;
    }

    public int getSortOrder() {
        return sortOrder;
    }

    public AdStatus getStatus() {
        return status;
    }

    public String getRejectionReason() {
        return rejectionReason;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
