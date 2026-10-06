package com.zairo.factory.staff;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.staff.StaffPortalDtos.DeclineAppointmentRequest;
import com.zairo.factory.staff.StaffPortalDtos.StaffAppointmentResponse;
import com.zairo.factory.staff.StaffPortalDtos.StaffMembershipResponse;
import com.zairo.factory.staff.StaffPortalDtos.StaffRatingResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** The signed-in staff member's own cabinet — works across every business they were added to. */
@RestController
@Tag(name = "Staff cabinet")
@SecurityRequirement(name = "bearerAuth")
public class StaffPortalController {

    private final StaffPortalService portalService;

    public StaffPortalController(StaffPortalService portalService) {
        this.portalService = portalService;
    }

    @Operation(summary = "My workplaces", description = "Every business the caller works at (empty list if "
            + "none) with the caller's pending-appointment count and rating there — the business switcher.")
    @ApiResponse(responseCode = "200", description = "The caller's staff profiles")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @GetMapping("/api/v1/me/staff-memberships")
    public List<StaffMembershipResponse> memberships(HttpServletRequest request) {
        return portalService.memberships(CurrentUser.requireUserId(request));
    }

    @Operation(summary = "My appointments at one business", description = "Only appointments booked with this "
            + "staff member. scope = ALL (default), UPCOMING (not yet over, confirmed or awaiting payment) or "
            + "HISTORY.")
    @ApiResponse(responseCode = "200", description = "Appointments, soonest first for UPCOMING, newest first otherwise")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/me/staff/{staffId}/appointments")
    public List<StaffAppointmentResponse> appointments(@PathVariable UUID staffId,
            @RequestParam(defaultValue = "ALL") StaffPortalService.Scope scope, HttpServletRequest request) {
        return portalService.appointments(CurrentUser.requireUserId(request), staffId, scope);
    }

    @Operation(summary = "Accept an appointment", description = "Acknowledges a confirmed appointment; the "
            + "booking's status doesn't change. Idempotent.")
    @ApiResponse(responseCode = "204", description = "Accepted")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The appointment isn't confirmed.")
    @PostMapping("/api/v1/me/staff/{staffId}/appointments/{bookingId}/accept")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void accept(@PathVariable UUID staffId, @PathVariable UUID bookingId, HttpServletRequest request) {
        portalService.accept(CurrentUser.requireUserId(request), staffId, bookingId);
    }

    @Operation(summary = "Cancel an appointment", description = "Releases the slot, refunds a paid booking and "
            + "notifies the customer — same effects as the customer cancelling.")
    @ApiResponse(responseCode = "204", description = "Cancelled")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The appointment can't be cancelled in its current state.")
    @PostMapping("/api/v1/me/staff/{staffId}/appointments/{bookingId}/cancel")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancel(@PathVariable UUID staffId, @PathVariable UUID bookingId,
            @RequestBody(required = false) DeclineAppointmentRequest body, HttpServletRequest request) {
        portalService.cancel(CurrentUser.requireUserId(request), staffId, bookingId,
                body == null ? null : body.reason());
    }

    @Operation(summary = "Mark an appointment completed", description = "Only a confirmed appointment; this is "
            + "what lets the customer leave a review.")
    @ApiResponse(responseCode = "204", description = "Completed")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The appointment isn't confirmed.")
    @PostMapping("/api/v1/me/staff/{staffId}/appointments/{bookingId}/complete")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void complete(@PathVariable UUID staffId, @PathVariable UUID bookingId, HttpServletRequest request) {
        portalService.complete(CurrentUser.requireUserId(request), staffId, bookingId);
    }

    @Operation(summary = "Mark a customer as no-show", description = "Only a confirmed appointment.")
    @ApiResponse(responseCode = "204", description = "Marked")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The appointment isn't confirmed.")
    @PostMapping("/api/v1/me/staff/{staffId}/appointments/{bookingId}/no-show")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void noShow(@PathVariable UUID staffId, @PathVariable UUID bookingId, HttpServletRequest request) {
        portalService.markNoShow(CurrentUser.requireUserId(request), staffId, bookingId);
    }

    @Operation(summary = "My rating at one business", description = "Average, star distribution and the "
            + "latest reviews left on appointments booked with this staff member.")
    @ApiResponse(responseCode = "200", description = "The rating")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/me/staff/{staffId}/rating")
    public StaffRatingResponse rating(@PathVariable UUID staffId, HttpServletRequest request) {
        return portalService.rating(CurrentUser.requireUserId(request), staffId);
    }
}
