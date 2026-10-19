package com.zairo.factory.workforce;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.workforce.WorkerPortalDtos.CannotAttendRequest;
import com.zairo.factory.workforce.WorkerPortalDtos.WorkerAppointmentResponse;
import com.zairo.factory.workforce.WorkerPortalDtos.WorkerMembershipResponse;
import com.zairo.factory.workforce.WorkerPortalDtos.WorkerRatingResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import com.zairo.factory.workforce.WorkerScheduleDtos.TimeOffCreatedResponse;
import com.zairo.factory.workforce.WorkerScheduleDtos.TimeOffRequest;
import com.zairo.factory.workforce.WorkerScheduleDtos.TimeOffResponse;
import jakarta.validation.Valid;
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
public class WorkerPortalController {

    private final WorkerPortalService portalService;
    private final WorkerTimeOffService timeOffService;

    public WorkerPortalController(WorkerPortalService portalService, WorkerTimeOffService timeOffService) {
        this.portalService = portalService;
        this.timeOffService = timeOffService;
    }

    @Operation(summary = "My workplaces", description = "Every business the caller works at (empty list if "
            + "none) with the caller's pending-appointment count and rating there — the business switcher.")
    @ApiResponse(responseCode = "200", description = "The caller's staff profiles")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @GetMapping("/api/v1/me/staff-memberships")
    public List<WorkerMembershipResponse> memberships() {
        return portalService.memberships(CurrentUser.requireUserId());
    }

    @Operation(summary = "My appointments at one business", description = "Only appointments booked with this "
            + "staff member. scope = ALL (default), UPCOMING (not yet over, confirmed or awaiting payment) or "
            + "HISTORY.")
    @ApiResponse(responseCode = "200", description = "Appointments, soonest first for UPCOMING, newest first otherwise")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/me/staff/{staffId}/appointments")
    public List<WorkerAppointmentResponse> appointments(@PathVariable UUID staffId,
            @RequestParam(defaultValue = "ALL") WorkerPortalService.Scope scope) {
        return portalService.appointments(CurrentUser.requireUserId(), staffId, scope);
    }

    @Operation(summary = "Accept an appointment", description = "Acknowledges a confirmed appointment; the "
            + "booking's status doesn't change. Idempotent.")
    @ApiResponse(responseCode = "204", description = "Accepted")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The appointment isn't confirmed.")
    @PostMapping("/api/v1/me/staff/{staffId}/appointments/{bookingId}/accept")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void accept(@PathVariable UUID staffId, @PathVariable UUID bookingId) {
        portalService.accept(CurrentUser.requireUserId(), staffId, bookingId);
    }

    @Operation(summary = "I can't attend this appointment", description = "A request to the business owner — "
            + "NOT a cancellation: the booking, the slot and the customer's payment are untouched, and the "
            + "owner is told and decides (reassign, move or cancel). Idempotent.")
    @ApiResponse(responseCode = "204", description = "The owner was notified")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The appointment is already over, completed or cancelled.")
    @PostMapping("/api/v1/me/staff/{staffId}/appointments/{bookingId}/cannot-attend")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cannotAttend(@PathVariable UUID staffId, @PathVariable UUID bookingId,
            @Valid @RequestBody(required = false) CannotAttendRequest body) {
        portalService.cannotAttend(CurrentUser.requireUserId(), staffId, bookingId,
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
    public void complete(@PathVariable UUID staffId, @PathVariable UUID bookingId) {
        portalService.complete(CurrentUser.requireUserId(), staffId, bookingId);
    }

    @Operation(summary = "Mark a customer as no-show", description = "Only a confirmed appointment.")
    @ApiResponse(responseCode = "204", description = "Marked")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The appointment isn't confirmed.")
    @PostMapping("/api/v1/me/staff/{staffId}/appointments/{bookingId}/no-show")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void noShow(@PathVariable UUID staffId, @PathVariable UUID bookingId) {
        portalService.markNoShow(CurrentUser.requireUserId(), staffId, bookingId);
    }

    @Operation(summary = "My rating at one business", description = "Average, star distribution and the "
            + "latest reviews left on appointments booked with this staff member.")
    @ApiResponse(responseCode = "200", description = "The rating")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/me/staff/{staffId}/rating")
    public WorkerRatingResponse rating(@PathVariable UUID staffId) {
        return portalService.rating(CurrentUser.requireUserId(), staffId);
    }

    @Operation(summary = "My upcoming time off", description = "Periods in which I can't be booked.")
    @ApiResponse(responseCode = "200", description = "Time off that hasn't ended yet")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @GetMapping("/api/v1/me/staff/{staffId}/time-off")
    public List<TimeOffResponse> timeOff(@PathVariable UUID staffId) {
        return timeOffService.listOwn(staffId, CurrentUser.requireUserId());
    }

    @Operation(summary = "I'm unavailable", description = "E.g. \"I'm sick today\": closes MY availability for the "
            + "period so no new bookings come in, and tells the owner. A worker can only ever reduce their own "
            + "availability — appointments already booked are untouched (the owner decides), and only the owner can "
            + "reopen the period.")
    @ApiResponse(responseCode = "201", description = "Recorded; says how many booked appointments fall inside")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @PostMapping("/api/v1/me/staff/{staffId}/time-off")
    @ResponseStatus(HttpStatus.CREATED)
    public TimeOffCreatedResponse markUnavailable(@PathVariable UUID staffId,
            @Valid @RequestBody TimeOffRequest body) {
        return timeOffService.createByWorker(staffId, CurrentUser.requireUserId(), body);
    }
}
