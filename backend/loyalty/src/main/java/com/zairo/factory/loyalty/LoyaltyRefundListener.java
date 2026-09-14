package com.zairo.factory.loyalty;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.payments.PaymentRefundedEvent;
import java.time.Clock;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Reacts to {@code payments.PaymentRefundedEvent} for the one case that
 * matters to loyalty: a booking that had already reached COMPLETED (and so
 * may have already earned points) whose payment is later refunded anyway
 * (e.g. a platform-admin dispute/chargeback correction via {@code
 * PaymentsService#refundPayment} -- see {@code PaymentAdminController}).
 * The ordinary cancel-before-completion path never reaches here: a
 * cancelled booking's own refund fires this same event, but {@code
 * booking.getStatus()} is CANCELLED by then, so this listener no-ops for
 * it -- consistent with this module's own package-info ("cancelled/no-show
 * bookings publish no completion event... nothing to reverse").
 *
 * <p>Same durability shape as {@link LoyaltyEarningListener}: a plain,
 * in-transaction {@link EventListener} that only writes a {@link
 * LoyaltyOutboxEvent} row (so it commits atomically with the refund and
 * survives a crash), never AFTER_COMMIT/best-effort. The actual points
 * clawback runs in {@link LoyaltyOutboxProcessor} via {@link
 * LoyaltyEarningProcessor#processPaymentRefunded}.
 */
@Component
class LoyaltyRefundListener {

    private static final Logger log = LoggerFactory.getLogger(LoyaltyRefundListener.class);

    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final LoyaltyOutboxEventRepository outboxRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    LoyaltyRefundListener(BookingRepository bookingRepository, AvailabilitySlotRepository availabilitySlotRepository,
            LoyaltyOutboxEventRepository outboxRepository, ApplicationEventPublisher eventPublisher, Clock clock) {
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.outboxRepository = outboxRepository;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
    }

    @EventListener
    @Transactional
    void onPaymentRefunded(PaymentRefundedEvent event) {
        Booking booking = bookingRepository.findById(event.bookingId()).orElse(null);
        if (booking == null || booking.getStatus() != BookingStatus.COMPLETED) {
            return;
        }
        AvailabilitySlot slot = availabilitySlotRepository.findById(booking.getAvailabilitySlotId()).orElse(null);
        if (slot == null) {
            log.error("Refunded booking {} has no resolvable availability slot -- cannot determine providerId for "
                    + "loyalty reversal", booking.getId());
            return;
        }
        LoyaltyOutboxEvent outboxEvent = outboxRepository.save(new LoyaltyOutboxEvent(UUID.randomUUID(),
                LoyaltyOutboxEventType.PAYMENT_REFUNDED, slot.getProviderId(), booking.getUserId(), booking.getId(),
                null, clock.instant()));
        eventPublisher.publishEvent(new LoyaltyOutboxEventReady(outboxEvent.getId()));
    }
}
