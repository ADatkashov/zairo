package com.zairo.factory.booking;

import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.subscriptions.SubscriptionLimitService;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@Service
public class BookingService {

    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final BookingRepository bookingRepository;
    private final ProviderRepository providerRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderOwnership providerOwnership;
    private final SubscriptionLimitService subscriptionLimitService;
    private final ApplicationEventPublisher eventPublisher;

    public BookingService(AvailabilitySlotRepository availabilitySlotRepository, BookingRepository bookingRepository,
            ProviderRepository providerRepository, ServiceOfferingRepository serviceOfferingRepository,
            ProviderOwnership providerOwnership, SubscriptionLimitService subscriptionLimitService,
            ApplicationEventPublisher eventPublisher) {
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.bookingRepository = bookingRepository;
        this.providerRepository = providerRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerOwnership = providerOwnership;
        this.subscriptionLimitService = subscriptionLimitService;
        this.eventPublisher = eventPublisher;
    }

    /**
     * Atomically claims the slot (OPEN -> BOOKED) and creates a booking in
     * one transaction — starting at {@link BookingStatus#PENDING_PAYMENT},
     * <b>not</b> CONFIRMED (see ADR-0006: a booking is never confirmed
     * without a successful payment). {@code @Version} on AvailabilitySlot
     * means a concurrent request for the same slot fails with
     * OptimisticLockingFailureException, which we turn into 409 — the slot
     * can't be double-booked even under concurrent requests.
     *
     * <p>Confirmation happens later, via {@link #confirmAfterPayment} —
     * called by {@code payments.PaymentsService} once a charge actually
     * succeeds (synchronously for the mock provider; via a verified
     * webhook for a real one). No {@link BookingConfirmedEvent} is
     * published here anymore — it moves to that method, so notifications
     * ("your booking is confirmed") never fire before payment does.
     */
    @Transactional
    public Booking createBooking(UUID userId, UUID serviceId, UUID availabilitySlotId, BigDecimal totalPrice) {
        AvailabilitySlot slot = availabilitySlotRepository.findById(availabilitySlotId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Availability slot not found: " + availabilitySlotId));

        if (slot.getStatus() != AvailabilityStatus.OPEN) {
            eventPublisher.publishEvent(new BookingAttemptedEvent(userId, serviceId, slot.getProviderId(), false,
                    "SLOT_NOT_OPEN"));
            throw new SlotNotAvailableException("Availability slot is not open: " + availabilitySlotId);
        }

        // ServiceOffering is the sole source of truth for what a booking
        // costs — see the totalPrice param's own note below. Its providerId
        // must match the slot's, the same exists-and-belongs-to-the-right-
        // provider check every vertical booking service (AutoBookingService,
        // BeautyBookingService, StaffBookingService, CleaningBookingService)
        // already runs for its own employee/service link before ever
        // reaching this method — a client can't mix a service from one
        // provider with a time slot from another.
        ServiceOffering service = serviceOfferingRepository.findById(serviceId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: "
                        + serviceId));
        if (!service.getProviderId().equals(slot.getProviderId())) {
            throw new SlotNotAvailableException("Service " + serviceId + " belongs to a different provider than "
                    + "availability slot " + availabilitySlotId);
        }

        Provider provider = providerRepository.findById(slot.getProviderId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: "
                        + slot.getProviderId()));
        YearMonth thisMonth = YearMonth.now(ZoneOffset.UTC);
        Instant monthStart = thisMonth.atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant monthEnd = thisMonth.plusMonths(1).atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant();
        long bookingsThisMonth = bookingRepository.countByProviderIdAndCreatedAtBetween(slot.getProviderId(),
                monthStart, monthEnd);
        subscriptionLimitService.checkCanCreateBooking(provider.getOwnerUserId(), (int) bookingsThisMonth);

        try {
            slot.markBooked();
            availabilitySlotRepository.saveAndFlush(slot);
        } catch (OptimisticLockingFailureException e) {
            eventPublisher.publishEvent(new BookingAttemptedEvent(userId, serviceId, slot.getProviderId(), false,
                    "SLOT_CLAIMED_CONCURRENTLY"));
            throw new SlotNotAvailableException("Availability slot was just booked by someone else: "
                    + availabilitySlotId);
        }

        // totalPrice (the method param) is deliberately never used here: a
        // client-supplied price would let the caller decide what a booking
        // costs, which is exactly the price-tampering hole this check
        // closes (see ServiceOffering lookup above). The param stays only so
        // every existing caller — BookingController and all four vertical
        // booking services (Auto/Beauty/Cleaning/Staff) — keeps compiling
        // unchanged; it no longer has any effect on the stored price.
        Booking booking = new Booking(UUID.randomUUID(), userId, serviceId, availabilitySlotId,
                BookingStatus.PENDING_PAYMENT, service.getPrice(), service.getCurrency(), Instant.now());
        booking = bookingRepository.save(booking);

        eventPublisher.publishEvent(new BookingAttemptedEvent(userId, serviceId, slot.getProviderId(), true, null));
        return booking;
    }

    /**
     * Called by {@code payments.PaymentsService} once a charge for this
     * booking actually succeeds. Idempotent by design: a booking that's
     * already past PENDING_PAYMENT (e.g. a duplicate webhook delivery, or
     * the sweep job and a late webhook racing) is returned as-is rather
     * than re-transitioned or erroring — see ADR-0006's Webhook
     * Architecture for why "already resolved" is a safe no-op here, not a
     * conflict.
     */
    @Transactional
    public Booking confirmAfterPayment(UUID bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));

        if (booking.getStatus() != BookingStatus.PENDING_PAYMENT) {
            return booking;
        }

        booking.markConfirmed();
        Booking confirmed = bookingRepository.save(booking);

        AvailabilitySlot slot = availabilitySlotRepository.findById(confirmed.getAvailabilitySlotId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + confirmed.getAvailabilitySlotId()));
        eventPublisher.publishEvent(new BookingConfirmedEvent(confirmed.getId(), confirmed.getUserId(),
                slot.getProviderId()));
        return confirmed;
    }

    /**
     * Called by {@link BookingPaymentTimeoutJob} for a booking that's simply
     * timed out unpaid — releases the slot the same way a customer
     * cancellation does. <b>Not</b> called by {@code payments.PaymentsService}
     * on a synchronous FAILED charge result — that's deliberately retriable
     * (see {@code PaymentsService.createPayment}'s reuse-the-FAILED-row
     * path): the booking stays PENDING_PAYMENT so a retried charge can still
     * confirm it, and only actually expires once the timeout elapses without
     * a successful retry. No {@link BookingCancelledEvent} here: unlike a
     * customer cancelling a CONFIRMED (paid) booking, there is by definition
     * nothing to refund — publishing the event would just be a guaranteed
     * no-op every time. Idempotent — already-resolved is a safe no-op, same
     * reasoning as {@link #confirmAfterPayment}.
     */
    @Transactional
    public Booking cancelUnpaidBooking(UUID bookingId, String reason) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));

        if (booking.getStatus() != BookingStatus.PENDING_PAYMENT) {
            return booking;
        }

        AvailabilitySlot slot = availabilitySlotRepository.findById(booking.getAvailabilitySlotId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + booking.getAvailabilitySlotId()));
        slot.markOpen();
        availabilitySlotRepository.save(slot);

        booking.markCancelled(reason);
        return bookingRepository.save(booking);
    }

    /**
     * Marks a confirmed booking as completed — the gate reviews checks
     * before accepting a review (see reviews module package-info: "no
     * review without a verified visit").
     */
    @Transactional
    public Booking completeBooking(UUID bookingId, UUID callerId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));

        AvailabilitySlot slot = availabilitySlotRepository.findById(booking.getAvailabilitySlotId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + booking.getAvailabilitySlotId()));
        providerOwnership.requireOwner(slot.getProviderId(), callerId);

        if (booking.getStatus() != BookingStatus.CONFIRMED) {
            throw new InvalidBookingStateException("Booking is not in a completable state: " + bookingId
                    + " (status=" + booking.getStatus() + ")");
        }

        booking.markCompleted();
        return bookingRepository.save(booking);
    }

    /**
     * Customer-initiated cancellation. A CONFIRMED (paid) or PENDING_PAYMENT
     * (not yet paid) booking can be cancelled — not PENDING/COMPLETED/
     * already-CANCELLED/NO_SHOW — mirrors completeBooking's status guard.
     * Releases the slot back to OPEN so someone else can book it, and
     * publishes {@link BookingCancelledEvent} so payments (refund) and
     * notifications can react without booking depending on either — same
     * ADR-0002 pattern as {@link BookingConfirmedEvent}. Cancelling from
     * PENDING_PAYMENT publishes the same event; the refund listener simply
     * finds no SUCCEEDED payment and no-ops — nothing was ever charged.
     *
     * <p>Deliberately no {@code @Version}-style optimistic locking here
     * (unlike the slot's OPEN->BOOKED claim): two different customers can
     * never race for the same booking, only the same customer double-
     * tapping cancel could — a much lower-stakes race than double-booking a
     * shared slot between strangers, and the status guard already rejects
     * the second call once the first has committed.
     */
    @Transactional
    public Booking cancelBooking(UUID bookingId, UUID callerId, String reason) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));

        if (!booking.getUserId().equals(callerId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You do not own this booking: " + bookingId);
        }

        if (booking.getStatus() != BookingStatus.CONFIRMED && booking.getStatus() != BookingStatus.PENDING_PAYMENT) {
            throw new InvalidBookingStateException("Booking is not in a cancellable state: " + bookingId
                    + " (status=" + booking.getStatus() + ")");
        }

        AvailabilitySlot slot = availabilitySlotRepository.findById(booking.getAvailabilitySlotId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + booking.getAvailabilitySlotId()));
        slot.markOpen();
        availabilitySlotRepository.save(slot);

        booking.markCancelled(reason);
        Booking cancelled = bookingRepository.save(booking);

        eventPublisher.publishEvent(new BookingCancelledEvent(cancelled.getId(), callerId, slot.getProviderId()));
        return cancelled;
    }

    /**
     * Provider-owner-initiated — the customer didn't show up for a
     * CONFIRMED slot. Same status guard as {@link #completeBooking}
     * (mutually exclusive terminal outcomes for a kept vs. missed
     * appointment), but ownership runs through the slot's provider
     * instead of the booking's own customer, mirroring how
     * {@code BookingController.listByProvider} resolves a provider from
     * a booking (Booking has no providerId of its own).
     */
    @Transactional
    public Booking markNoShow(UUID bookingId, UUID callerId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));

        if (booking.getStatus() != BookingStatus.CONFIRMED) {
            throw new InvalidBookingStateException("Booking is not in a no-show-able state: " + bookingId
                    + " (status=" + booking.getStatus() + ")");
        }

        AvailabilitySlot slot = availabilitySlotRepository.findById(booking.getAvailabilitySlotId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + booking.getAvailabilitySlotId()));
        providerOwnership.requireOwner(slot.getProviderId(), callerId);

        booking.markNoShow();
        return bookingRepository.save(booking);
    }

    /**
     * {@link BookingReminderJob}'s one call — marks each qualifying booking
     * reminded and publishes {@link BookingReminderDueEvent} for
     * notifications to actually email, in the same transaction as the
     * write (so a crash between marking and publishing can't happen: both
     * commit together, or neither does). Public (not package-private, like
     * the job itself) so tests can drive it deterministically instead of
     * waiting on the real 5-minute cadence — same reasoning as {@code
     * SubscriptionRenewalService.renewDueSubscriptions} being public.
     */
    @Transactional
    public void sendDueReminders(Instant now, Instant reminderCutoff) {
        for (Booking booking : bookingRepository.findConfirmedBookingsStartingBeforeAndNotYetReminded(now,
                reminderCutoff)) {
            booking.markReminderSent(now);
            bookingRepository.save(booking);
            eventPublisher.publishEvent(new BookingReminderDueEvent(booking.getId(), booking.getUserId()));
        }
    }
}
