package com.zairo.factory.smartfill;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.smartfill.SmartFillDtos.CandidateOfferResponse;
import com.zairo.factory.smartfill.SmartFillDtos.SmartFillPreferenceResponse;
import com.zairo.factory.smartfill.SmartFillDtos.UpdateSmartFillPreferenceRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

/**
 * The minimal customer-facing surface Smart Fill needs -- there is no
 * separate "accept" endpoint: the CTA in a Smart Fill notification leads
 * straight into the existing {@code POST /api/v1/bookings} flow using the
 * {@code providerId}/{@code serviceId}/{@code availabilitySlotId} this
 * offer's own response already carries, and {@code
 * booking.AvailabilitySlotBookedEvent} closes the loop back to ACCEPTED (see
 * {@code SmartFillCampaignService#completeCampaignsForBookedSlot}) once that
 * booking actually happens. Owner-facing performance data lives under
 * {@code provider-insights} instead (see {@code SmartFillAnalyticsService}).
 */
@RestController
@Tag(name = "Smart Fill")
public class SmartFillController {

    private final CandidateOfferRepository offerRepository;
    private final SmartFillCampaignRepository campaignRepository;
    private final SmartFillUserPreferenceRepository preferenceRepository;

    public SmartFillController(CandidateOfferRepository offerRepository,
            SmartFillCampaignRepository campaignRepository, SmartFillUserPreferenceRepository preferenceRepository) {
        this.offerRepository = offerRepository;
        this.campaignRepository = campaignRepository;
        this.preferenceRepository = preferenceRepository;
    }

    @Operation(summary = "List a user's Smart Fill offers", description = """
            Owner-only: the caller must be the exact user named by `userId`. Every offer this user has ever \
            been sent, newest first. Listing has a side effect: any NOTIFIED offer returned is marked VIEWED \
            (see CandidateOfferStatus) -- same "viewing is the signal" reasoning as \
            notifications.NotificationsController's own feed.""")
    @ApiResponse(responseCode = "200", description = "The user's offers (empty list if none)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/smart-fill-offers")
    public List<CandidateOfferResponse> list(@Parameter(description = "The user's id.") @PathVariable UUID userId,
            HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        if (!callerId.equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot view another user's Smart Fill offers");
        }

        List<CandidateOffer> offers = offerRepository.findByUserIdOrderByCreatedAtDesc(userId);
        if (offers.isEmpty()) {
            return List.of();
        }

        for (CandidateOffer offer : offers) {
            if (offer.getStatus() == CandidateOfferStatus.NOTIFIED) {
                offer.markViewed();
            }
        }
        offerRepository.saveAll(offers);

        Map<UUID, SmartFillCampaign> campaignsById = campaignRepository
                .findAllById(offers.stream().map(CandidateOffer::getCampaignId).distinct().toList()).stream()
                .collect(Collectors.toMap(SmartFillCampaign::getId, c -> c));

        return offers.stream()
                .filter(offer -> campaignsById.containsKey(offer.getCampaignId()))
                .map(offer -> CandidateOfferResponse.from(offer, campaignsById.get(offer.getCampaignId())))
                .toList();
    }

    @Operation(summary = "Get a user's Smart Fill preference", description = "Owner-only. Absent a prior "
            + "update, a user is opted in by default (optedOut=false).")
    @ApiResponse(responseCode = "200", description = "The user's current preference")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/smart-fill-preference")
    public SmartFillPreferenceResponse getPreference(
            @Parameter(description = "The user's id.") @PathVariable UUID userId, HttpServletRequest httpRequest) {
        UUID callerId = requireSelf(userId, httpRequest);
        return preferenceRepository.findByUserId(callerId)
                .map(SmartFillPreferenceResponse::from)
                .orElse(new SmartFillPreferenceResponse(callerId, false));
    }

    @Operation(summary = "Opt in/out of Smart Fill suggestions", description = "Owner-only. Opting out stops "
            + "this user from ever being offered a freed slot again (see NotificationPolicy); it does not "
            + "affect any other notification category.")
    @ApiResponse(responseCode = "200", description = "Preference updated")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/users/{userId}/smart-fill-preference")
    public SmartFillPreferenceResponse updatePreference(
            @Parameter(description = "The user's id.") @PathVariable UUID userId,
            @Valid @RequestBody UpdateSmartFillPreferenceRequest request, HttpServletRequest httpRequest) {
        UUID callerId = requireSelf(userId, httpRequest);
        SmartFillUserPreference preference = preferenceRepository.findByUserId(callerId)
                .orElseGet(() -> new SmartFillUserPreference(callerId, false, Instant.now()));
        preference.update(request.optedOut(), Instant.now());
        return SmartFillPreferenceResponse.from(preferenceRepository.save(preference));
    }

    private static UUID requireSelf(UUID userId, HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        if (!callerId.equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot manage another user's Smart Fill preference");
        }
        return callerId;
    }
}
