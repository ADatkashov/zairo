package com.zairo.factory.automation;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.DateTimeException;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.UUID;

/**
 * One row per provider, created on first access as an all-defaults draft
 * (every engine enabled, every tuning override null -- meaning "use the
 * platform's global default"). This is an opt-out model: the three engines
 * already run for every provider today with no settings row at all, so
 * absence of a row must mean "behave exactly as before", never "disabled".
 */
@Entity
@Table(name = "automation_settings")
public class AutomationSettings {

    @Id
    private UUID id;

    @Column(name = "provider_id", nullable = false, unique = true)
    private UUID providerId;

    @Column(name = "rebook_enabled", nullable = false)
    private boolean rebookEnabled;

    @Column(name = "reactivation_enabled", nullable = false)
    private boolean reactivationEnabled;

    @Column(name = "smart_fill_enabled", nullable = false)
    private boolean smartFillEnabled;

    /** Null overrides below mean "use rebookengine.RebookProperties' own global default" -- never zero/absent-as-off. */
    @Column(name = "rebook_min_visits_to_establish_interval")
    private Integer rebookMinVisitsToEstablishInterval;

    @Column(name = "rebook_min_interval_days")
    private Integer rebookMinIntervalDays;

    @Column(name = "rebook_max_interval_days")
    private Integer rebookMaxIntervalDays;

    @Column(name = "rebook_follow_up_window_days")
    private Integer rebookFollowUpWindowDays;

    /** Null overrides below mean "use reactivationengine.ReactivationProperties' own global default". */
    @Column(name = "reactivation_scan_min_inactivity_days")
    private Integer reactivationScanMinInactivityDays;

    @Column(name = "reactivation_interval_multiplier")
    private Double reactivationIntervalMultiplier;

    @Column(name = "reactivation_absolute_max_inactivity_days")
    private Integer reactivationAbsoluteMaxInactivityDays;

    @Column(name = "reactivation_follow_up_window_days")
    private Integer reactivationFollowUpWindowDays;

    /** Both null = no restriction at all (24/7, today's actual behavior). Either set without the other is rejected -- see the service's validation. */
    @Column(name = "allowed_hours_start")
    private Integer allowedHoursStart;

    @Column(name = "allowed_hours_end")
    private Integer allowedHoursEnd;

    /** An IANA zone id (e.g. "Asia/Almaty") the allowed-hours window is interpreted in. Null = UTC. */
    @Column(name = "timezone")
    private String timezone;

    /** Minimum days between two offers of the same engine to the same customer at this provider. Null = no cooldown. */
    @Column(name = "cooldown_days_between_offers")
    private Integer cooldownDaysBetweenOffers;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Version
    private long version;

    protected AutomationSettings() {
    }

    AutomationSettings(UUID id, UUID providerId, Instant now) {
        this.id = id;
        this.providerId = providerId;
        this.rebookEnabled = true;
        this.reactivationEnabled = true;
        this.smartFillEnabled = true;
        this.createdAt = now;
        this.updatedAt = now;
    }

    void applySettings(boolean rebookEnabled, boolean reactivationEnabled, boolean smartFillEnabled,
            Integer rebookMinVisitsToEstablishInterval, Integer rebookMinIntervalDays, Integer rebookMaxIntervalDays,
            Integer rebookFollowUpWindowDays, Integer reactivationScanMinInactivityDays,
            Double reactivationIntervalMultiplier, Integer reactivationAbsoluteMaxInactivityDays,
            Integer reactivationFollowUpWindowDays, Integer allowedHoursStart, Integer allowedHoursEnd, String timezone,
            Integer cooldownDaysBetweenOffers, Instant now) {
        this.rebookEnabled = rebookEnabled;
        this.reactivationEnabled = reactivationEnabled;
        this.smartFillEnabled = smartFillEnabled;
        this.rebookMinVisitsToEstablishInterval = rebookMinVisitsToEstablishInterval;
        this.rebookMinIntervalDays = rebookMinIntervalDays;
        this.rebookMaxIntervalDays = rebookMaxIntervalDays;
        this.rebookFollowUpWindowDays = rebookFollowUpWindowDays;
        this.reactivationScanMinInactivityDays = reactivationScanMinInactivityDays;
        this.reactivationIntervalMultiplier = reactivationIntervalMultiplier;
        this.reactivationAbsoluteMaxInactivityDays = reactivationAbsoluteMaxInactivityDays;
        this.reactivationFollowUpWindowDays = reactivationFollowUpWindowDays;
        this.allowedHoursStart = allowedHoursStart;
        this.allowedHoursEnd = allowedHoursEnd;
        this.timezone = timezone;
        this.cooldownDaysBetweenOffers = cooldownDaysBetweenOffers;
        this.updatedAt = now;
    }

    /**
     * True if {@code now}, converted into this business's own timezone (UTC
     * if none set), falls inside the allowed-hours window -- or if there's
     * no window configured at all, which is always true (today's actual
     * behavior: every engine can send around the clock). Handles a window
     * that wraps midnight (e.g. 9-22 does not, but 20-6 does) the same way
     * either direction reads naturally: "allowed from start up to end".
     * Falls back to allowing everything for a timezone string that somehow
     * became invalid after being validated at write time, rather than ever
     * silently blocking every send for this provider.
     */
    boolean isWithinAllowedHours(Instant now) {
        if (allowedHoursStart == null || allowedHoursEnd == null || allowedHoursStart.equals(allowedHoursEnd)) {
            return true;
        }
        int hour;
        try {
            ZoneId zone = timezone == null ? ZoneId.of("UTC") : ZoneId.of(timezone);
            hour = ZonedDateTime.ofInstant(now, zone).getHour();
        } catch (DateTimeException e) {
            return true;
        }
        if (allowedHoursStart < allowedHoursEnd) {
            return hour >= allowedHoursStart && hour < allowedHoursEnd;
        }
        return hour >= allowedHoursStart || hour < allowedHoursEnd;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public boolean isRebookEnabled() {
        return rebookEnabled;
    }

    public boolean isReactivationEnabled() {
        return reactivationEnabled;
    }

    public boolean isSmartFillEnabled() {
        return smartFillEnabled;
    }

    public Integer getRebookMinVisitsToEstablishInterval() {
        return rebookMinVisitsToEstablishInterval;
    }

    public Integer getRebookMinIntervalDays() {
        return rebookMinIntervalDays;
    }

    public Integer getRebookMaxIntervalDays() {
        return rebookMaxIntervalDays;
    }

    public Integer getRebookFollowUpWindowDays() {
        return rebookFollowUpWindowDays;
    }

    public Integer getReactivationScanMinInactivityDays() {
        return reactivationScanMinInactivityDays;
    }

    public Double getReactivationIntervalMultiplier() {
        return reactivationIntervalMultiplier;
    }

    public Integer getReactivationAbsoluteMaxInactivityDays() {
        return reactivationAbsoluteMaxInactivityDays;
    }

    public Integer getReactivationFollowUpWindowDays() {
        return reactivationFollowUpWindowDays;
    }

    public Integer getAllowedHoursStart() {
        return allowedHoursStart;
    }

    public Integer getAllowedHoursEnd() {
        return allowedHoursEnd;
    }

    public String getTimezone() {
        return timezone;
    }

    public Integer getCooldownDaysBetweenOffers() {
        return cooldownDaysBetweenOffers;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
