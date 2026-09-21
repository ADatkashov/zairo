package com.zairo.factory.payments;

import com.zairo.factory.payments.PaymentDtos.PaymentResponse;
import com.zairo.factory.payments.PaymentDtos.RefundRequestResponse;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Read-only — PLATFORM_ADMIN or PLATFORM_SUPPORT (see
 * {@link PlatformCurrentAdmin#requireAnyRole}, no mutation here). Surfaces
 * what {@code Payment.refundFailureReason}/{@code refundAttempts} already
 * capture (see that entity's own doc comment) so it stops being something
 * only a log line or a direct DB query could answer — a business/customer
 * still owed money is a real support/finance question, not just an
 * engineering one.
 */
@RestController
@Tag(name = "Platform Admin — Payments")
public class PaymentAdminController {

    private static final int REFUND_REQUEST_LIST_LIMIT = 200;

    private final PaymentRepository paymentRepository;
    private final PaymentRefundRequestRepository refundRequestRepository;

    public PaymentAdminController(PaymentRepository paymentRepository,
            PaymentRefundRequestRepository refundRequestRepository) {
        this.paymentRepository = paymentRepository;
        this.refundRequestRepository = refundRequestRepository;
    }

    @Operation(summary = "List payments with a currently-failed refund", description = """
            Money that was never successfully returned to a customer — the payment's own retry \
            (`POST /payments/{id}/refund`) is still available for these, this is purely visibility. \
            Ordered most-recent first.""")
    @ApiResponse(responseCode = "200", description = "Failed-refund payments")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/payments/failed-refunds")
    public List<PaymentResponse> failedRefunds(HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requireAnyRole(httpRequest);
        return paymentRepository.findByStatusOrderByCreatedAtDesc(PaymentStatus.REFUND_FAILED).stream()
                .map(PaymentResponse::from)
                .toList();
    }

    @Operation(summary = "List durable refund-outbox requests by status", description = """
            The durable retry queue a cancelled booking's refund goes through (see \
            `docs/adr/0006-payment-provider-freedompay.md`'s "Durable Refund Outbox" section) — attempts, \
            last error, and next scheduled retry for troubleshooting a refund that hasn't resolved yet. \
            `FAILED` rows are the ones that exhausted retries and need human attention (the same payment \
            also shows up in `GET .../failed-refunds` once that happens). Ordered most-recent first, \
            capped at the 200 most recent matching rows.""")
    @ApiResponse(responseCode = "200", description = "Refund-outbox requests in the given status")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/payments/refund-requests")
    public List<RefundRequestResponse> refundRequests(
            @Parameter(description = "Which status to list.") @RequestParam PaymentRefundRequestStatus status,
            HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requireAnyRole(httpRequest);
        return refundRequestRepository.findByStatusOrderByCreatedAtDesc(status,
                        PageRequest.of(0, REFUND_REQUEST_LIST_LIMIT)).stream()
                .map(RefundRequestResponse::from)
                .toList();
    }
}
