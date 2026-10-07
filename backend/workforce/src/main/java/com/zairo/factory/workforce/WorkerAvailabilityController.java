package com.zairo.factory.workforce;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.booking.AvailabilitySlotDtos.AvailabilitySlotResponse;
import com.zairo.factory.workforce.WorkerAvailabilityDtos.AnySlotResponse;
import com.zairo.factory.workforce.WorkerAvailabilityDtos.BookAnyRequest;
import com.zairo.factory.workforce.WorkerAvailabilityDtos.BookAnyResponse;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** What a customer sees when picking a person or "any master", and booking with "any master". */
@RestController
@Tag(name = "Workforce — booking")
public class WorkerAvailabilityController {

    private final WorkerAvailabilityService availabilityService;
    private final WorkerAnyBookingService anyBookingService;

    public WorkerAvailabilityController(WorkerAvailabilityService availabilityService,
            WorkerAnyBookingService anyBookingService) {
        this.availabilityService = availabilityService;
        this.anyBookingService = anyBookingService;
    }

    @Operation(summary = "Times to book with one person", description = "Only times when the person actually works, "
            + "isn't off and isn't already booked anywhere. Uses the person's own schedule when the owner set one, "
            + "otherwise the business's shared slots. Empty when the business doesn't let customers choose a "
            + "person. No authentication required.")
    @ApiResponse(responseCode = "200", description = "Open times, soonest first")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/providers/{providerId}/workers/{workerId}/availability")
    public List<AvailabilitySlotResponse> forWorker(@PathVariable UUID providerId, @PathVariable UUID workerId) {
        return availabilityService.forWorker(providerId, workerId);
    }

    @Operation(summary = "Times to book with \"any master\"", description = "Merged times of everyone who performs the "
            + "service; each carries the person the system would assign (the least busy). No authentication "
            + "required.")
    @ApiResponse(responseCode = "200", description = "Open times, soonest first")
    @GetMapping("/api/v1/providers/{providerId}/availability/any")
    public List<AnySlotResponse> forAny(@PathVariable UUID providerId, @RequestParam UUID serviceId) {
        return availabilityService.forAny(providerId, serviceId);
    }

    @Operation(summary = "Book with \"any master\"", description = "Self-service. The customer picks a time (from "
            + "GET .../availability/any), the system assigns a free person and books through their directory. The "
            + "booking remembers the customer didn't mind who, so the business may swap the person later.")
    @ApiResponse(responseCode = "201", description = "Booked (status PENDING_PAYMENT, like any booking)")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "409", description = "That time is no longer available.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers/{providerId}/bookings/any")
    @ResponseStatus(HttpStatus.CREATED)
    public BookAnyResponse bookAny(@PathVariable UUID providerId, @Valid @RequestBody BookAnyRequest body,
            HttpServletRequest request) {
        return anyBookingService.book(providerId, CurrentUser.requireUserId(request), body);
    }
}
