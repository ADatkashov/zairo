package com.zairo.factory.workforce;

import com.zairo.factory.workforce.WorkerDirectoryDtos.TopWorkerResponse;
import com.zairo.factory.workforce.WorkerDirectoryDtos.WorkerProfileResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
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
            + "to qualify. `limit` is clamped to 1-20. No authentication required.")
    @ApiResponse(responseCode = "200", description = "Best first; empty when nobody qualifies yet")
    @GetMapping("/api/v1/workers/top")
    public List<TopWorkerResponse> top(@RequestParam(defaultValue = "10") int limit) {
        return service.top(limit);
    }

    @Operation(summary = "A worker's public page", description = "Name, photo, business, rating and the services "
            + "they perform. No authentication required.")
    @ApiResponse(responseCode = "200", description = "The worker")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/workers/{workerId}")
    public WorkerProfileResponse profile(@PathVariable UUID workerId) {
        return service.profile(workerId);
    }
}
