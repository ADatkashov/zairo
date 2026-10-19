package com.zairo.factory.workforce;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.workforce.WorkerDirectoryDtos.BookingWorkerResponse;
import com.zairo.factory.workforce.WorkerDirectoryDtos.TopWorkerResponse;
import com.zairo.factory.workforce.WorkerDirectoryDtos.WorkerProfileResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Public, read-only: the customer app's "best masters" rail and a worker's page. */
@RestController
@Tag(name = "Workforce — directory")
public class WorkerDirectoryController {

    private final WorkerDirectoryService service;

    public WorkerDirectoryController(WorkerDirectoryService service) {
        this.service = service;
    }

    @Operation(summary = "Best-rated workers", description = "Active masters, mechanics, cleaners and staff of "
            + "ACTIVE businesses ranked by the average rating of the reviews on their bookings; at least 3 reviews "
            + "to qualify. `limit` is clamped to 1-20. With `city` (a city code) only businesses of that city and "
            + "those that have not set a city yet are counted. No authentication required.")
    @ApiResponse(responseCode = "200", description = "Best first; empty when nobody qualifies yet")
    @GetMapping("/api/v1/workers/top")
    public List<TopWorkerResponse> top(@RequestParam(defaultValue = "10") int limit,
            @RequestParam(required = false) String city) {
        return service.top(limit, city);
    }

    @Operation(summary = "A worker's public page", description = "Name, photo, business, rating and the services "
            + "they perform. No authentication required.")
    @ApiResponse(responseCode = "200", description = "The worker")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/workers/{workerId}")
    public WorkerProfileResponse profile(@PathVariable UUID workerId) {
        return service.profile(workerId);
    }

    @Operation(summary = "Who a booking is with", description = "The person (master, mechanic, cleaner or staff) "
            + "this booking is with. Only the customer who made the booking.")
    @ApiResponse(responseCode = "200", description = "The person")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", description = "No such booking, or it has no named person.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/bookings/{bookingId}/worker")
    public BookingWorkerResponse ofBooking(@PathVariable UUID bookingId) {
        return service.workerOfBooking(bookingId, CurrentUser.requireUserId());
    }
}
