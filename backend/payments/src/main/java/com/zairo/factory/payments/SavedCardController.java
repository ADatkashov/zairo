package com.zairo.factory.payments;

import com.zairo.factory.auth.CurrentUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Saved cards")
public class SavedCardController {

    private final SavedCardService savedCardService;

    public SavedCardController(SavedCardService savedCardService) {
        this.savedCardService = savedCardService;
    }

    public record SavedCardResponse(UUID id, @Schema(example = "VISA", nullable = true) String brand,
            @Schema(example = "4242", nullable = true) String last4, Instant addedAt) {
        static SavedCardResponse from(SavedCard card) {
            return new SavedCardResponse(card.getId(), card.getCardBrand(), card.getCardLast4(), card.getCreatedAt());
        }
    }

    public record SavedCardsResponse(List<SavedCardResponse> cards,
            @Schema(description = "The next online payment also saves the card used.") boolean saveOnNextPayment,
            @Schema(description = "True when a saved card can be charged right away. False means the provider "
                    + "cannot do that yet, so saved cards are kept but payments still go through its payment page.")
            boolean canPayWithSavedCard) {
    }

    public record SavePreferenceRequest(@NotNull Boolean saveOnNextPayment) {
    }

    @Operation(summary = "My saved cards", description = "Brand and last four digits only.")
    @ApiResponse(responseCode = "200", description = "The caller's saved cards (possibly none)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/me/payment-cards")
    public SavedCardsResponse list(HttpServletRequest httpRequest) {
        UUID userId = CurrentUser.requireUserId(httpRequest);
        return new SavedCardsResponse(
                savedCardService.list(userId).stream().map(SavedCardResponse::from).toList(),
                savedCardService.saveOnNextPayment(userId), savedCardService.canPayWithSavedCard());
    }

    @Operation(summary = "Choose whether the next payment saves the card",
            description = "A provider can only create a reusable card during a real payment, so saving is a "
                    + "switch the next online payment honours.")
    @ApiResponse(responseCode = "200", description = "Stored")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/me/payment-cards/preference")
    public SavedCardsResponse setPreference(@Valid @RequestBody SavePreferenceRequest request,
            HttpServletRequest httpRequest) {
        UUID userId = CurrentUser.requireUserId(httpRequest);
        savedCardService.setSaveOnNextPayment(userId, request.saveOnNextPayment());
        return list(httpRequest);
    }

    @Operation(summary = "Remove a saved card", description = "Forgets the card on our side so it is never "
            + "charged again.")
    @ApiResponse(responseCode = "204", description = "Removed")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "Not one of the caller's cards.")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/me/payment-cards/{cardId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remove(@PathVariable UUID cardId, HttpServletRequest httpRequest) {
        savedCardService.remove(cardId, CurrentUser.requireUserId(httpRequest));
    }
}
