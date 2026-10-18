package com.zairo.factory.automation;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.automation.AutomationDtos.AutomationSettingsResponse;
import com.zairo.factory.automation.AutomationDtos.UpdateAutomationSettingsRequest;
import com.zairo.factory.providers.OwnsProvider;
import com.zairo.factory.providers.ProviderOwnership;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * Owner-only settings for the Automation Center -- unifies Smart Fill,
 * Rebook and Reactivation's per-business configuration in one place, same
 * "one screen, one settings row" shape {@code loyalty}'s own program
 * settings already use.
 */
@RestController
@Tag(name = "Business Admin: Automation Center")
public class AutomationSettingsController {

    private final AutomationSettingsService settingsService;
    private final ProviderOwnership providerOwnership;

    public AutomationSettingsController(AutomationSettingsService settingsService,
            ProviderOwnership providerOwnership) {
        this.settingsService = settingsService;
        this.providerOwnership = providerOwnership;
    }

    @Operation(summary = "This business's automation settings",
            description = "Creates an all-enabled, all-default draft on first access -- never 404s for an owned provider.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/business/{providerId}/automation/settings")
    @OwnsProvider
    public AutomationSettingsResponse getSettings(@PathVariable UUID providerId, HttpServletRequest httpRequest) {
        return AutomationSettingsResponse.from(settingsService.getOrCreateDraft(providerId));
    }

    @Operation(summary = "Update this business's automation settings")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/business/{providerId}/automation/settings")
    @OwnsProvider
    public AutomationSettingsResponse updateSettings(@PathVariable UUID providerId,
            @RequestBody UpdateAutomationSettingsRequest request, HttpServletRequest httpRequest) {
        return AutomationSettingsResponse.from(settingsService.updateSettings(providerId, request));
    }
}
