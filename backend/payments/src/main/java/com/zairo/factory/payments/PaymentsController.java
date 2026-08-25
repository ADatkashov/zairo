package com.zairo.factory.payments;

import com.zairo.factory.payments.PaymentDtos.PaymentResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@Tag(name = "Payments")
public class PaymentsController {

    private final PaymentsService paymentsService;
    private final PaymentRepository paymentRepository;

    public PaymentsController(PaymentsService paymentsService, PaymentRepository paymentRepository) {
        this.paymentsService = paymentsService;
        this.paymentRepository = paymentRepository;
    }

    @Operation(summary = "Charge a booking", description = """
            Charges the booking's total price through the (mock, local-dev) payment provider. \
            **A declined charge is still a 201** — check the response body's `status` field \
            (SUCCEEDED/FAILED), not just the HTTP status: a card decline is a normal business outcome, \
            not a server error. Retrying after a FAILED charge reuses the same Payment row (and the same \
            `id` as the idempotency key sent to the provider) rather than creating a new one — safe to \
            retry the exact same request.

            **Workflow**: `Create booking -> Charge -> ...` — the booking must exist first.""")
    @ApiResponse(responseCode = "201", description = "Charge attempted — see `status` in the body for the "
            + "real outcome")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The booking doesn't exist.")
    @ApiResponse(responseCode = "409", description = "This booking already has a payment that isn't FAILED "
            + "(so there's nothing to retry).",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/bookings/{bookingId}/payments")
    @ResponseStatus(HttpStatus.CREATED)
    public PaymentResponse createPayment(@Parameter(description = "The booking's id.") @PathVariable UUID bookingId) {
        return PaymentResponse.from(paymentsService.createPayment(bookingId));
    }

    @Operation(summary = "Get a booking's payment")
    @ApiResponse(responseCode = "200", description = "The payment")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "This booking has no payment yet.")
    @GetMapping("/api/v1/bookings/{bookingId}/payments")
    public PaymentResponse getPaymentForBooking(
            @Parameter(description = "The booking's id.") @PathVariable UUID bookingId) {
        return paymentRepository.findByBookingId(bookingId).map(PaymentResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "No payment for booking: " + bookingId));
    }

    @Operation(summary = "Refund a payment", description = "Only a SUCCEEDED payment can be refunded.")
    @ApiResponse(responseCode = "200", description = "Refunded — status is now REFUNDED")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The payment isn't SUCCEEDED (already refunded, still "
            + "pending, or failed).",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "502", description = "The payment provider rejected the refund itself.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/payments/{paymentId}/refund")
    public PaymentResponse refund(@Parameter(description = "The payment's id.") @PathVariable UUID paymentId) {
        return PaymentResponse.from(paymentsService.refundPayment(paymentId));
    }
}
