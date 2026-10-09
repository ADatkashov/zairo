package com.zairo.factory.payments;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.payments.OfflinePaymentDtos.RecordPaymentRequest;
import com.zairo.factory.payments.PaymentDtos.PaymentResponse;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Payments")
public class PaymentsController {

    /** Optional body: pay with one of the caller's saved cards instead of the provider's payment page. */
    public record CreatePaymentRequest(
            @Schema(description = "One of the caller's saved cards (GET /api/v1/me/payment-cards). Only the "
                    + "booking's own customer can use it; the card is charged right away.", nullable = true)
            UUID savedCardId) {
    }

    private final PaymentsService paymentsService;
    private final PaymentAllocationRepository allocationRepository;

    public PaymentsController(PaymentsService paymentsService, PaymentAllocationRepository allocationRepository) {
        this.paymentsService = paymentsService;
        this.allocationRepository = allocationRepository;
    }

    @Operation(summary = "Charge a booking", description = """
            Charges the booking's total price through the configured payment provider. Restricted to the \
            booking's own customer, or the owner of the provider the booking's slot belongs to.

            **A declined/pending charge is still a 201** — check the response body's `status` field, not just \
            the HTTP status: SUCCEEDED (mock, or a real provider confirming instantly) confirms the booking \
            right away; PENDING (a real, redirect-based provider) means nothing is confirmed yet — redirect the \
            customer to `checkoutUrl` and wait for the webhook; FAILED is a normal business outcome (declined \
            card), not a server error, and the booking stays open for a retry. Retrying after a FAILED charge \
            reuses the same Payment row (and the same `id` as the idempotency key sent to the provider) rather \
            than creating a new one — safe to retry the exact same request.

            **Workflow**: `Create booking -> Charge -> ...` — the booking must exist first.""")
    @ApiResponse(responseCode = "201", description = "Charge attempted — see `status` (and `checkoutUrl` if "
            + "PENDING) in the body for the real outcome")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is neither the booking's own customer nor "
            + "the owner of the provider it belongs to.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The booking doesn't exist.")
    @ApiResponse(responseCode = "409", description = "Either the booking isn't awaiting payment (its status "
            + "isn't PENDING_PAYMENT), or it already has a payment that isn't FAILED (so there's nothing to "
            + "retry).",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/bookings/{bookingId}/payments")
    @ResponseStatus(HttpStatus.CREATED)
    public PaymentResponse createPayment(@Parameter(description = "The booking's id.") @PathVariable UUID bookingId,
            @RequestBody(required = false) CreatePaymentRequest request, HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        UUID savedCardId = request == null ? null : request.savedCardId();
        return toResponse(paymentsService.createPayment(bookingId, callerId, savedCardId));
    }

    @Operation(summary = "Get a booking's payment", description = "Restricted to the booking's own customer, "
            + "or the owner of the provider the booking's slot belongs to.")
    @ApiResponse(responseCode = "200", description = "The payment")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is neither the booking's own customer nor "
            + "the owner of the provider it belongs to.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The booking doesn't exist, or it "
            + "exists but has no payment yet.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/bookings/{bookingId}/payments")
    public PaymentResponse getPaymentForBooking(
            @Parameter(description = "The booking's id.") @PathVariable UUID bookingId,
            HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        return toResponse(paymentsService.getPaymentForBooking(bookingId, callerId));
    }

    @Operation(summary = "Refund a payment", description = "PLATFORM_ADMIN-only — same platform-admin "
            + "authorization as GET /platform/payments/failed-refunds, whose own doc comment already "
            + "describes this endpoint as the failed-refund retry path. Only a SUCCEEDED payment can be "
            + "refunded.")
    @ApiResponse(responseCode = "200", description = "Refunded — status is now REFUNDED")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "The payment isn't SUCCEEDED (already refunded, still "
            + "pending, or failed).",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "502", description = "The payment provider rejected the refund itself.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/payments/{paymentId}/refund")
    public PaymentResponse refund(@Parameter(description = "The payment's id.") @PathVariable UUID paymentId,
            HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requirePlatformAdmin(httpRequest);
        return toResponse(paymentsService.refundPayment(paymentId));
    }

    @Operation(summary = "Record an offline payment", description = """
            Record a payment made through a non-online method (cash, card at location, etc).
            Restricted to the owner of the provider the booking's slot belongs to.

            This endpoint allows businesses to record payments they received outside of ZAIRO's
            payment provider. Once recorded, it updates the booking's payment status accordingly.""")
    @ApiResponse(responseCode = "201", description = "Payment recorded successfully")
    @ApiResponse(responseCode = "400", description = "Invalid payment method or amount",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller is not the owner of the provider",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The booking doesn't exist")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/bookings/{bookingId}/offline-payment")
    @ResponseStatus(HttpStatus.CREATED)
    public OfflinePaymentDtos.PaymentResponse recordOfflinePayment(
            @Parameter(description = "The booking's id.") @PathVariable UUID bookingId,
            @Valid @RequestBody RecordPaymentRequest request, HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        Payment payment = paymentsService.recordOfflinePayment(bookingId, request.amount(), request.method(), callerId);
        return OfflinePaymentDtos.PaymentResponse.from(payment);
    }

    /** Attaches the commission split (see PaymentAllocation) when one exists — null fields until the payment SUCCEEDED. */
    private PaymentResponse toResponse(Payment payment) {
        return PaymentResponse.from(payment, allocationRepository.findByPaymentId(payment.getId()).orElse(null));
    }
}
