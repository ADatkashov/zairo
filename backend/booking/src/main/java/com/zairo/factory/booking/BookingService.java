package com.zairo.factory.booking;

import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.subscriptions.SubscriptionLimitService;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
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
    private final ProviderOwnership providerOwnership;
    private final SubscriptionLimitService subscriptionLimitService;
    private final ApplicationEventPublisher eventPublisher;
    private final String defaultCurrency;

    public BookingService(AvailabilitySlotRepository availabilitySlotRepository, BookingRepository bookingRepository,
            ProviderRepository providerRepository, ProviderOwnership providerOwnership,
            SubscriptionLimitService subscriptionLimitService, ApplicationEventPublisher eventPublisher,
            @Value("${app.platform.default-currency:USD}") String defaultCurrency) {
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.bookingRepository = bookingRepository;
        this.providerRepository = providerRepository;
        this.providerOwnership = providerOwnership;
        this.subscriptionLimitService = subscriptionLimitService;
        this.eventPublisher = eventPublisher;
        this.defaultCurrency = defaultCurrency;
    }

    /**
     * Atomically claims the slot (OPEN -> BOOKED) and creates a confirmed
     * booking in one transaction. {@code @Version} on AvailabilitySlot means
     * a concurrent request for the same slot fails with
     * OptimisticLockingFailureException, which we turn into 409 — the slot
     * can't be double-booked even under concurrent requests.
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

        // No per-service currency lookup yet (booking deliberately doesn't
        // depend on services — see the class doc) — same single-market MVP
        // assumption Payment used to make independently, now one config
        // value instead of two that happened to agree.
        Booking booking = new Booking(UUID.randomUUID(), userId, serviceId, availabilitySlotId,
                BookingStatus.CONFIRMED, totalPrice, defaultCurrency, Instant.now());
        booking = bookingRepository.save(booking);

        eventPublisher.publishEvent(new BookingConfirmedEvent(booking.getId(), userId, slot.getProviderId()));
        eventPublisher.publishEvent(new BookingAttemptedEvent(userId, serviceId, slot.getProviderId(), true, null));
        return booking;
    }

    /**
     * Marks a confirmed booking as completed — the gate reviews checks
     * before accepting a review (see reviews module package-info: "no
     * review without a verified visit").
     */
    @Transactional
    public Booking completeBooking(UUID bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));

        if (booking.getStatus() != BookingStatus.CONFIRMED) {
            throw new InvalidBookingStateException("Booking is not in a completable state: " + bookingId
                    + " (status=" + booking.getStatus() + ")");
        }

        booking.markCompleted();
        return bookingRepository.save(booking);
    }

    /**
     * Customer-initiated cancellation. Only a CONFIRMED booking can be
     * cancelled (not PENDING/COMPLETED/already-CANCELLED) — mirrors
     * completeBooking's status guard. Releases the slot back to OPEN so
     * someone else can book it, and publishes {@link BookingCancelledEvent}
     * so payments (refund) and notifications can react without booking
     * depending on either — same ADR-0002 pattern as
     * {@link BookingConfirmedEvent}.
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

        if (booking.getStatus() != BookingStatus.CONFIRMED) {
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
}
