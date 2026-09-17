package com.zairo.factory.customerintelligence;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingCancelledEvent;
import com.zairo.factory.booking.BookingCompletedEvent;
import com.zairo.factory.booking.BookingConfirmedEvent;
import com.zairo.factory.booking.BookingNoShowEvent;
import com.zairo.factory.booking.BookingRepository;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Keeps every affected profile fresh as a customer's real booking history
 * changes -- see this module's own package-info ("computed on events, not
 * on read"). Same {@code @TransactionalEventListener(AFTER_COMMIT)} pattern
 * every other domain-event consumer in this codebase uses (ADR-0002):
 * booking has no idea this module exists.
 *
 * <p>Listens for {@link BookingConfirmedEvent} rather than a booking's
 * initial creation -- a {@code PENDING_PAYMENT} booking that never gets
 * paid is not a real, countable customer interaction yet (see {@code
 * BookingStatus}'s own doc comment); {@code BookingConfirmedEvent} is this
 * codebase's actual "a booking really happened" signal. A booking that
 * times out unpaid (see {@code BookingPaymentTimeoutJob}) publishes no
 * event at all, so it never reaches these profiles either -- consistent,
 * since it was never confirmed in the first place.
 */
@Component
class CustomerIntelligenceBookingListener {

    private final CustomerIntelligenceService service;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;

    CustomerIntelligenceBookingListener(CustomerIntelligenceService service, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository) {
        this.service = service;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingConfirmed(BookingConfirmedEvent event) {
        recalculate(event.userId(), event.providerId(), event.bookingId());
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingCompleted(BookingCompletedEvent event) {
        recalculate(event.userId(), event.providerId(), event.bookingId());
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingCancelled(BookingCancelledEvent event) {
        recalculate(event.userId(), event.providerId(), event.bookingId());
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingNoShow(BookingNoShowEvent event) {
        recalculate(event.userId(), event.providerId(), event.bookingId());
    }

    private void recalculate(UUID userId, UUID providerId, UUID bookingId) {
        service.recalculateProfile(userId);
        service.recalculateProviderProfile(userId, providerId);

        UUID employeeId = resolveEmployeeId(bookingId);
        if (employeeId != null) {
            service.recalculateEmployeeProfile(userId, providerId, employeeId);
        }
    }

    private UUID resolveEmployeeId(UUID bookingId) {
        return bookingRepository.findById(bookingId).map(Booking::getAvailabilitySlotId)
                .flatMap(availabilitySlotRepository::findById).map(AvailabilitySlot::getEmployeeId).orElse(null);
    }
}
