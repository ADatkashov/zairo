package com.zairo.factory.workforce;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.workforce.WorkerOwnerDtos.NeedsAttentionResponse;
import com.zairo.factory.workforce.WorkerOwnerDtos.OwnerCancelRequest;
import com.zairo.factory.workforce.WorkerOwnerDtos.ReassignRequest;
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
public class WorkerOwnerController {

    private final WorkerOwnerService ownerService;

    public WorkerOwnerController(WorkerOwnerService ownerService) {
        this.ownerService = ownerService;
    }

    @Operation(summary = "Appointments that need my decision", description = "Owner-only. Upcoming appointments "
            + "whose person said they can't attend, is off then, or no longer works here — soonest first, each with "
            + "the colleagues who could take it. Customers who said \"any master\" are handed over automatically "
            + "and don't appear unless nobody was free.")
    @ApiResponse(responseCode = "200", description = "The list (empty when nothing needs a decision)")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/providers/{providerId}/appointments/needs-attention")
    public List<NeedsAttentionResponse> needsAttention(@PathVariable UUID providerId, HttpServletRequest request) {
        return ownerService.needsAttention(providerId, CurrentUser.requireUserId(request));
    }

    @Operation(summary = "Give an appointment to a colleague", description = "Owner-only. The colleague must be of "
            + "the same kind, perform the service and be free then (the owner may pick someone outside their usual "
            + "hours). The customer is told who will serve them; no customer consent is needed.")
    @ApiResponse(responseCode = "204", description = "Reassigned")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "That person can't take this appointment.")
    @PostMapping("/api/v1/providers/{providerId}/appointments/{bookingId}/reassign")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void reassign(@PathVariable UUID providerId, @PathVariable UUID bookingId,
            @Valid @RequestBody ReassignRequest body, HttpServletRequest request) {
        ownerService.reassign(providerId, bookingId, CurrentUser.requireUserId(request), body.workerId());
    }

    @Operation(summary = "Ask the customer to decide", description = "Owner-only. For a customer who chose this "
            + "person: they are told and pick a colleague at the same time, another time, or cancel with a refund. "
            + "Idempotent.")
    @ApiResponse(responseCode = "204", description = "The customer was asked")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "Nothing needs a decision for this appointment.")
    @PostMapping("/api/v1/providers/{providerId}/appointments/{bookingId}/ask-customer")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void askCustomer(@PathVariable UUID providerId, @PathVariable UUID bookingId, HttpServletRequest request) {
        ownerService.askCustomer(providerId, bookingId, CurrentUser.requireUserId(request));
    }

    @Operation(summary = "Cancel an appointment (owner)", description = "Owner-only. Releases the slot, refunds a "
            + "paid booking and notifies the customer. Only the owner can cancel with a refund — a worker can only ask.")
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
