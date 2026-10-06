package com.zairo.factory.staff;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.staff.StaffOwnerDtos.NeedsAttentionResponse;
import com.zairo.factory.staff.StaffOwnerDtos.OwnerCancelRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Business-owner endpoints about staff-related appointments. */
@RestController
@Tag(name = "Staff — owner")
@SecurityRequirement(name = "bearerAuth")
public class StaffOwnerController {

    private final StaffOwnerService ownerService;

    public StaffOwnerController(StaffOwnerService ownerService) {
        this.ownerService = ownerService;
    }

    @Operation(summary = "Appointments that need my decision", description = "Owner-only. Upcoming appointments "
            + "where a staff member said they can't attend, soonest first.")
    @ApiResponse(responseCode = "200", description = "The list (empty when nothing needs a decision)")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/providers/{providerId}/appointments/needs-attention")
    public List<NeedsAttentionResponse> needsAttention(@PathVariable UUID providerId, HttpServletRequest request) {
        return ownerService.needsAttention(providerId, CurrentUser.requireUserId(request));
    }

    @Operation(summary = "Cancel an appointment (owner)", description = "Owner-only. Releases the slot, refunds a "
            + "paid booking and notifies the customer. Only the owner can cancel with a refund — staff can only ask.")
    @ApiResponse(responseCode = "204", description = "Cancelled")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The appointment can't be cancelled in its current state.")
    @PostMapping("/api/v1/providers/{providerId}/appointments/{bookingId}/cancel")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancel(@PathVariable UUID providerId, @PathVariable UUID bookingId,
            @Valid @RequestBody(required = false) OwnerCancelRequest body, HttpServletRequest request) {
        ownerService.cancel(providerId, bookingId, CurrentUser.requireUserId(request),
                body == null ? null : body.reason());
    }
}
