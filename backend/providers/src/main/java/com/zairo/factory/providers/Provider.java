package com.zairo.factory.providers;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * {@code vertical} is stored and returned as-is; this module never parses or
 * branches on its value — see docs/erd/core-domain.md.
 */
@Entity
@Table(name = "provider")
public class Provider {

    @Id
    private UUID id;

    @Column(name = "owner_user_id", nullable = false)
    private UUID ownerUserId;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String vertical;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ProviderStatus status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /**
     * Nullable — set directly by the caller (curl/seed data/future business
     * onboarding UI), no geocoding-from-address step. A real address ->
     * lat/lng lookup would need an external geocoding service; deferred
     * along with everything else map-related that needs a real provider
     * account (see search module's distance ranking and
     * apps/user_app/lib/features/maps/).
     */
    @Column
    private Double latitude;

    @Column
    private Double longitude;

    /**
     * References {@code catalog.BusinessType} by bare id — nullable because
     * existing rows predate the master catalog (backfilled once, see
     * V25__create_catalog_tables.sql) and, in principle, {@code vertical}
     * strings that don't map to a seeded BusinessType code could still leave
     * this unset. {@code vertical} remains the field every existing call
     * site reads; this is additive, not a replacement, until those call
     * sites migrate deliberately.
     */
    @Column(name = "business_type_id")
    private UUID businessTypeId;

    /**
     * Nullable — no photo until the owner uploads one via the generic
     * storage module (backend/storage) and PUTs the returned URL through
     * here. Same "renders a gradient placeholder instead" story on the
     * client as staff/master/mechanic/cleaner photoUrl (see V42) had before
     * this column existed for the provider itself.
     */
    @Column(name = "cover_photo_url")
    private String coverPhotoUrl;

    /**
     * The city the business works in (a {@code city.code}); null until the owner picks one, and then the business
     * counts as "everywhere" in city-narrowed lists so nothing disappears while owners are filling their profile in.
     */
    @Column(name = "city_code")
    private String cityCode;

    protected Provider() {
    }

    public Provider(UUID id, UUID ownerUserId, String name, String vertical, ProviderStatus status,
            Instant createdAt) {
        this(id, ownerUserId, name, vertical, status, createdAt, null, null, null);
    }

    public Provider(UUID id, UUID ownerUserId, String name, String vertical, ProviderStatus status,
            Instant createdAt, Double latitude, Double longitude) {
        this(id, ownerUserId, name, vertical, status, createdAt, latitude, longitude, null);
    }

    public Provider(UUID id, UUID ownerUserId, String name, String vertical, ProviderStatus status,
            Instant createdAt, Double latitude, Double longitude, UUID businessTypeId) {
        this.id = id;
        this.ownerUserId = ownerUserId;
        this.name = name;
        this.vertical = vertical;
        this.status = status;
        this.createdAt = createdAt;
        this.latitude = latitude;
        this.longitude = longitude;
        this.businessTypeId = businessTypeId;
    }

    public UUID getId() {
        return id;
    }

    public UUID getOwnerUserId() {
        return ownerUserId;
    }

    public String getName() {
        return name;
    }

    public String getVertical() {
        return vertical;
    }

    public ProviderStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Double getLatitude() {
        return latitude;
    }

    public Double getLongitude() {
        return longitude;
    }

    public UUID getBusinessTypeId() {
        return businessTypeId;
    }

    public String getCoverPhotoUrl() {
        return coverPhotoUrl;
    }

    /**
     * Owner-editable fields only — {@code vertical} isn't here on purpose
     * (changing it would orphan vertical-specific data like beauty
     * masters), and neither is {@code status} (a moderation/lifecycle
     * field, not something the owner self-toggles — no admin console
     * exists yet to drive it either, so it stays PENDING/whatever it was).
     */
    void update(String name, Double latitude, Double longitude, String coverPhotoUrl) {
        this.name = name;
        this.latitude = latitude;
        this.longitude = longitude;
        this.coverPhotoUrl = coverPhotoUrl;
    }

    /** Same as {@link #update(String, Double, Double, String)}, and sets the city unless {@code cityCode} is null/blank (keep). */
    void update(String name, Double latitude, Double longitude, String coverPhotoUrl, String cityCode) {
        update(name, latitude, longitude, coverPhotoUrl);
        if (cityCode != null && !cityCode.isBlank()) {
            this.cityCode = cityCode.trim();
        }
    }

    /** Sets the city at creation; null/blank leaves it unset. */
    void assignCity(String cityCode) {
        this.cityCode = cityCode == null || cityCode.isBlank() ? null : cityCode.trim();
    }

    public String getCityCode() {
        return cityCode;
    }

    /** Admin-only moderation action — see ProviderController's status endpoint. */
    void updateStatus(ProviderStatus status) {
        this.status = status;
    }
}
