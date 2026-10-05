package com.zairo.factory.invitations;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.invitations.InvitationDtos.CreateInvitationRequest;
import com.zairo.factory.invitations.InvitationDtos.InvitationResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Staff invitations")
public class InvitationController {

    private final InvitationService invitationService;

    public InvitationController(InvitationService invitationService) {
        this.invitationService = invitationService;
    }

    @Operation(summary = "Invite a person who has no account yet", description = "Owner-only. When the person "
            + "verifies this phone number (sign-up or linking), they are added to the business as a master, "
            + "mechanic, cleaner or staff member — whichever fits the business's category. For someone already "
            + "registered, add them directly (GET /users/lookup).")
    @ApiResponse(responseCode = "201", description = "Invitation created")
    @ApiResponse(responseCode = "400", description = "Not a valid phone number.")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "This number is already invited to this business.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers/{providerId}/staff-invitations")
    @ResponseStatus(HttpStatus.CREATED)
    public InvitationResponse create(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Valid @RequestBody CreateInvitationRequest request, HttpServletRequest httpRequest) {
        return InvitationResponse.from(invitationService.invite(providerId, request.phone(),
                CurrentUser.requireUserId(httpRequest)));
    }

    @Operation(summary = "List a business's pending invitations", description = "Owner-only.")
    @ApiResponse(responseCode = "200", description = "Pending invitations, newest first")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/staff-invitations")
    public List<InvitationResponse> list(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            HttpServletRequest httpRequest) {
        return invitationService.listPending(providerId, CurrentUser.requireUserId(httpRequest)).stream()
                .map(InvitationResponse::from).toList();
    }

    @Operation(summary = "Cancel a pending invitation", description = "Owner-only, idempotent.")
    @ApiResponse(responseCode = "204", description = "Cancelled (or nothing to cancel)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/staff-invitations/{invitationId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancel(@Parameter(description = "The invitation's id.") @PathVariable UUID invitationId,
            HttpServletRequest httpRequest) {
        invitationService.cancel(invitationId, CurrentUser.requireUserId(httpRequest));
    }
}
