package com.zairo.factory.payments;

import com.zairo.factory.payments.PaymentDtos.PaymentResponse;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class PaymentsController {

    private final PaymentsService paymentsService;
    private final PaymentRepository paymentRepository;

    public PaymentsController(PaymentsService paymentsService, PaymentRepository paymentRepository) {
        this.paymentsService = paymentsService;
        this.paymentRepository = paymentRepository;
    }

    @PostMapping("/api/v1/bookings/{bookingId}/payments")
    @ResponseStatus(HttpStatus.CREATED)
    public PaymentResponse createPayment(@PathVariable UUID bookingId) {
        return PaymentResponse.from(paymentsService.createPayment(bookingId));
    }

    @GetMapping("/api/v1/bookings/{bookingId}/payments")
    public PaymentResponse getPaymentForBooking(@PathVariable UUID bookingId) {
        return paymentRepository.findByBookingId(bookingId).map(PaymentResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "No payment for booking: " + bookingId));
    }

    @PostMapping("/api/v1/payments/{paymentId}/refund")
    public PaymentResponse refund(@PathVariable UUID paymentId) {
        return PaymentResponse.from(paymentsService.refundPayment(paymentId));
    }
}
