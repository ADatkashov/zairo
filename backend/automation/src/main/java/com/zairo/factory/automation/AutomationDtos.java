package com.zairo.factory.automation;

import io.swagger.v3.oas.annotations.media.Schema;

public final class AutomationDtos {

    private AutomationDtos() {
    }

    public record AutomationSettingsResponse(
            boolean rebookEnabled, boolean reactivationEnabled, boolean smartFillEnabled,
            @Schema(description = "Null = use the platform default.") Integer rebookMinVisitsToEstablishInterval,
            Integer rebookMinIntervalDays, Integer rebookMaxIntervalDays, Integer rebookFollowUpWindowDays,
            Integer reactivationScanMinInactivityDays, Double reactivationIntervalMultiplier,
            Integer reactivationAbsoluteMaxInactivityDays, Integer reactivationFollowUpWindowDays,
            @Schema(description = "Both null = no quiet hours (24/7).") Integer allowedHoursStart,
            Integer allowedHoursEnd,
            @Schema(description = "IANA zone id, e.g. \"Asia/Almaty\". Null = UTC.", example = "Asia/Almaty")
            String timezone,
            @Schema(description = "Null = no cooldown.") Integer cooldownDaysBetweenOffers) {

        static AutomationSettingsResponse from(AutomationSettings s) {
            return new AutomationSettingsResponse(s.isRebookEnabled(), s.isReactivationEnabled(),
                    s.isSmartFillEnabled(), s.getRebookMinVisitsToEstablishInterval(), s.getRebookMinIntervalDays(),
                    s.getRebookMaxIntervalDays(), s.getRebookFollowUpWindowDays(),
                    s.getReactivationScanMinInactivityDays(), s.getReactivationIntervalMultiplier(),
                    s.getReactivationAbsoluteMaxInactivityDays(), s.getReactivationFollowUpWindowDays(),
                    s.getAllowedHoursStart(), s.getAllowedHoursEnd(), s.getTimezone(), s.getCooldownDaysBetweenOffers());
        }
    }

    /** Every override field is optional (null = fall back to the platform's global default for that engine). */
    public record UpdateAutomationSettingsRequest(
            boolean rebookEnabled, boolean reactivationEnabled, boolean smartFillEnabled,
            Integer rebookMinVisitsToEstablishInterval, Integer rebookMinIntervalDays, Integer rebookMaxIntervalDays,
            Integer rebookFollowUpWindowDays, Integer reactivationScanMinInactivityDays,
            Double reactivationIntervalMultiplier, Integer reactivationAbsoluteMaxInactivityDays,
            Integer reactivationFollowUpWindowDays, Integer allowedHoursStart, Integer allowedHoursEnd, String timezone,
            Integer cooldownDaysBetweenOffers) {
    }
}
