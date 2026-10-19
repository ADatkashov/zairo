package com.zairo.factory.workforce;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.workforce.WorkerPricingDtos.ServiceWorkerPriceResponse;
import com.zairo.factory.workforce.WorkerPricingDtos.SetWorkerPriceRequest;
import com.zairo.factory.workforce.WorkerPricingDtos.WorkerPriceResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/** Different prices per master — set by the owner, shown to the customer when they pick that master. */
@RestController
@Tag(name = "Workforce — pricing")
public class WorkerPricingController {

    private final WorkerPricingService pricingService;

    public WorkerPricingController(WorkerPricingService pricingService) {
        this.pricingService = pricingService;
    }

    @Operation(summary = "A worker's own prices", description = "Owner-only. Services where this worker charges "
            + "something other than the service's price.")
    @ApiResponse(responseCode = "200", description = "The prices")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/workers/{workerId}/prices")
    public List<WorkerPriceResponse> prices(@PathVariable UUID providerId, @PathVariable UUID workerId) {
        return pricingService.ofWorker(providerId, workerId, CurrentUser.requireUserId());
    }

    @Operation(summary = "Set or clear a worker's price for a service", description = "Owner-only. A null price or "
            + "the service's own price removes the override. Takes effect only while the business has per-worker "
            + "prices switched on, and never changes bookings already made.")
    @ApiResponse(responseCode = "200", description = "The worker's prices after the change")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/providers/{providerId}/workers/{workerId}/prices")
    public List<WorkerPriceResponse> setPrice(@PathVariable UUID providerId, @PathVariable UUID workerId,
            @Valid @RequestBody SetWorkerPriceRequest body) {
        return pricingService.set(providerId, workerId, CurrentUser.requireUserId(), body);
    }

    @Operation(summary = "Worker prices for a service (public)", description = "Who charges something other than "
            + "the service's price, so the booking screen shows the right amount when a customer picks that person. "
            + "Empty when the business doesn't use per-worker prices.")
    @ApiResponse(responseCode = "200", description = "The differing prices")
    @GetMapping("/api/v1/providers/{providerId}/services/{serviceId}/worker-prices")
    public List<ServiceWorkerPriceResponse> forService(@PathVariable UUID providerId, @PathVariable UUID serviceId) {
        return pricingService.forService(providerId, serviceId);
    }
}
