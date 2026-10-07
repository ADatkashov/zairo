package com.zairo.factory.payments;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PaymentPartialRefundRepository extends JpaRepository<PaymentPartialRefund, UUID> {

    List<PaymentPartialRefund> findByPaymentId(UUID paymentId);

    List<PaymentPartialRefund> findByStatusNot(PaymentPartialRefund.Status status);

    /** Everything decided to go back to the customer so far (returned or still owed). */
    @Query("select coalesce(sum(r.amount), 0) from PaymentPartialRefund r where r.paymentId = :paymentId")
    BigDecimal totalForPayment(@Param("paymentId") UUID paymentId);

    /** The business share those refunds take away from the payout. */
    @Query("select coalesce(sum(r.amount - r.platformFeeReturned), 0) from PaymentPartialRefund r "
            + "where r.paymentId = :paymentId")
    BigDecimal businessShareForPayment(@Param("paymentId") UUID paymentId);
}
