package com.zairo.factory.workforce;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.workforce.WorkerScheduleDtos.SaveScheduleRequest;
import com.zairo.factory.workforce.WorkerScheduleDtos.SaveScheduleResult;
import com.zairo.factory.workforce.WorkerScheduleDtos.ScheduleResponse;
import com.zairo.factory.workforce.WorkerScheduleDtos.TimeOffCreatedResponse;
import com.zairo.factory.workforce.WorkerScheduleDtos.TimeOffRequest;
import com.zairo.factory.workforce.WorkerScheduleDtos.TimeOffResponse;
import com.zairo.factory.workforce.WorkerScheduleDtos.UpdateWorkforceSettingsRequest;
import com.zairo.factory.workforce.WorkerScheduleDtos.WorkerSummaryResponse;
import com.zairo.factory.workforce.WorkerScheduleDtos.WorkforceSettingsResponse;
import io.swagger.v3.oas.annotations.Operation;
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
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** The business owner's team schedule: weekly hours, time off ("the master isn't in") and worker rules. */
@RestController
@Tag(name = "Workforce — schedule")
public class WorkerScheduleController {

    private final WorkerScheduleService scheduleService;
    private final WorkerTimeOffService timeOffService;
    private final WorkforceSettingsService settingsService;
    private final WorkerPortalService portalService;

    public WorkerScheduleController(WorkerScheduleService scheduleService, WorkerTimeOffService timeOffService,
            WorkforceSettingsService settingsService, WorkerPortalService portalService) {
        this.scheduleService = scheduleService;
        this.timeOffService = timeOffService;
        this.settingsService = settingsService;
        this.portalService = portalService;
    }

    @Operation(summary = "The business's workers", description = "Owner-only. Every master / mechanic / cleaner / "
            + "staff member of the business, with whether they have their own weekly schedule and whether they are "
            + "off right now.")
    @ApiResponse(responseCode = "200", description = "The workers")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/workers")
    public List<WorkerSummaryResponse> workers(@PathVariable UUID providerId, HttpServletRequest request) {
        return scheduleService.workers(providerId, CurrentUser.requireUserId(request));
    }

    @Operation(summary = "A worker's rating and reviews", description = "Owner-only. Average rating (the person's own "
            + "rating where the customer gave one, else the shared one), the star distribution and the newest "
            + "reviews with the reviewer's name, for one master / mechanic / cleaner / staff member of the business.")
    @ApiResponse(responseCode = "200", description = "The rating")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/workers/{workerId}/rating")
    public WorkerPortalDtos.WorkerRatingResponse rating(@PathVariable UUID providerId, @PathVariable UUID workerId,
            HttpServletRequest request) {
        return portalService.ratingOf(
                scheduleService.requireOwnerOfWorker(providerId, workerId, CurrentUser.requireUserId(request)));
    }

    @Operation(summary = "A worker's weekly schedule", description = "Owner-only. configured=false means the worker "
            + "still uses the business's shared slots.")
    @ApiResponse(responseCode = "200", description = "The schedule")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/workers/{workerId}/schedule")
    public ScheduleResponse getSchedule(@PathVariable UUID providerId, @PathVariable UUID workerId,
            HttpServletRequest request) {
        return scheduleService.get(providerId, workerId, CurrentUser.requireUserId(request));
    }

    @Operation(summary = "Set a worker's weekly schedule", description = "Owner-only. Replaces the weekly hours and "
            + "generates the worker's own bookable slots for the next 28 days (kept up to date daily). Slots already "
            + "booked are never touched. Only the owner can set a schedule.")
    @ApiResponse(responseCode = "200", description = "Saved; reports how many slots were created and removed")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/providers/{providerId}/workers/{workerId}/schedule")
    public SaveScheduleResult saveSchedule(@PathVariable UUID providerId, @PathVariable UUID workerId,
            @Valid @RequestBody SaveScheduleRequest body, HttpServletRequest request) {
        return scheduleService.save(providerId, workerId, CurrentUser.requireUserId(request), body);
    }

    @Operation(summary = "Remove a worker's own schedule", description = "Owner-only. The worker goes back to the "
            + "business's shared slots; their own open slots are removed, booked ones stay.")
    @ApiResponse(responseCode = "204", description = "Removed (or there was none)")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/providers/{providerId}/workers/{workerId}/schedule")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteSchedule(@PathVariable UUID providerId, @PathVariable UUID workerId,
            HttpServletRequest request) {
        scheduleService.delete(providerId, workerId, CurrentUser.requireUserId(request));
    }

    @Operation(summary = "A worker's upcoming time off", description = "Owner-only.")
    @ApiResponse(responseCode = "200", description = "Time off that hasn't ended yet")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/workers/{workerId}/time-off")
    public List<TimeOffResponse> listTimeOff(@PathVariable UUID providerId, @PathVariable UUID workerId,
            HttpServletRequest request) {
        return timeOffService.list(providerId, workerId, CurrentUser.requireUserId(request));
    }

    @Operation(summary = "The master isn't in", description = "Owner-only. Closes the worker's availability for the "
            + "period: new bookings stop immediately. Appointments already booked in the period are NOT cancelled — "
            + "the response says how many, and the owner decides what to do with each.")
    @ApiResponse(responseCode = "201", description = "Recorded")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers/{providerId}/workers/{workerId}/time-off")
    @ResponseStatus(HttpStatus.CREATED)
    public TimeOffCreatedResponse createTimeOff(@PathVariable UUID providerId, @PathVariable UUID workerId,
            @Valid @RequestBody TimeOffRequest body, HttpServletRequest request) {
        return timeOffService.createByOwner(providerId, workerId, CurrentUser.requireUserId(request), body);
    }

    @Operation(summary = "The worker is available again", description = "Owner-only. Removes a time-off period.")
    @ApiResponse(responseCode = "204", description = "Removed")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/providers/{providerId}/time-off/{timeOffId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteTimeOff(@PathVariable UUID providerId, @PathVariable UUID timeOffId,
            HttpServletRequest request) {
        timeOffService.delete(providerId, timeOffId, CurrentUser.requireUserId(request));
    }

    @Operation(summary = "Worker rules of a business", description = "Public: the booking screen needs "
            + "allowWorkerChoice to decide whether to offer a choice of master.")
    @ApiResponse(responseCode = "200", description = "The settings (defaults when the owner never set any)")
    @GetMapping("/api/v1/providers/{providerId}/workforce-settings")
    public WorkforceSettingsResponse getSettings(@PathVariable UUID providerId) {
        return settingsService.get(providerId);
    }

    @Operation(summary = "Change a business's worker rules", description = "Owner-only. allowWorkerChoice: whether "
            + "customers may pick a specific person (otherwise only \"any master\"); workerPricingEnabled: whether "
            + "the owner sets a different price per worker.")
    @ApiResponse(responseCode = "200", description = "Saved")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/providers/{providerId}/workforce-settings")
    public WorkforceSettingsResponse updateSettings(@PathVariable UUID providerId,
            @RequestBody UpdateWorkforceSettingsRequest body, HttpServletRequest request) {
        return settingsService.update(providerId, CurrentUser.requireUserId(request), body);
    }
}
