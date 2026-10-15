package com.zairo.factory.workforce;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.workforce.WorkerDirectoryDtos.BookingWorkerResponse;
import com.zairo.factory.workforce.WorkerDirectoryDtos.TopWorkerResponse;
import com.zairo.factory.workforce.WorkerDirectoryDtos.WorkerProfileResponse;
import com.zairo.factory.workforce.WorkerDirectoryDtos.WorkerReviewResponse;
import com.zairo.factory.workforce.WorkerDirectoryDtos.WorkerServiceResponse;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/** The customer-facing side of the workers: who the best ones are, and a worker's public page. */
@Service
public class WorkerDirectoryService {

    /** Reviews a worker needs before they can appear among the best. */
    static final int MIN_REVIEWS_FOR_TOP = 3;

    static final int MAX_TOP = 20;

    /** How many of the newest reviews a worker's page shows. */
    static final int PROFILE_REVIEWS = 3;

    private final WorkerCatalog catalog;
    private final ProviderRepository providerRepository;
    private final BookingRepository bookingRepository;

    public WorkerDirectoryService(WorkerCatalog catalog, ProviderRepository providerRepository,
            BookingRepository bookingRepository) {
        this.catalog = catalog;
        this.providerRepository = providerRepository;
        this.bookingRepository = bookingRepository;
    }

    @Transactional(readOnly = true)
    public List<TopWorkerResponse> top(int limit, String city) {
        return catalog.topRated(MIN_REVIEWS_FOR_TOP, clampLimit(limit), blankToNull(city)).stream()
                .map(TopWorkerResponse::from).toList();
    }

    static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    static int clampLimit(int limit) {
        return Math.max(1, Math.min(limit, MAX_TOP));
    }

    /** 404 for an unknown or deactivated worker, and for one whose business is not ACTIVE (not publicly listed). */
    @Transactional(readOnly = true)
    public WorkerProfileResponse profile(UUID workerId) {
        Worker worker = catalog.find(workerId).filter(Worker::active)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Worker not found: " + workerId));
        Provider provider = providerRepository.findById(worker.providerId())
                .filter(p -> p.getStatus() == ProviderStatus.ACTIVE)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Worker not found: " + workerId));
        WorkerCatalog.Ranked rating = catalog.ratingOf(worker, provider.getName());
        List<WorkerServiceResponse> services = catalog.servicesOf(worker).stream()
                .map(s -> new WorkerServiceResponse(s.id(), s.title(), s.durationMinutes(), s.price(), s.currency()))
                .toList();
        List<WorkerReviewResponse> reviews = catalog.latestReviews(worker, PROFILE_REVIEWS).stream()
                .map(r -> new WorkerReviewResponse(r.rating(), r.comment(), r.createdAt(), r.businessReply()))
                .toList();
        return new WorkerProfileResponse(worker.id(), worker.kind(), provider.getId(), provider.getName(),
                worker.displayName(), worker.photoUrl(), catalog.bioOf(worker).orElse(null),
                rating.reviewCount() == 0 ? null : Math.round(rating.averageRating() * 10) / 10.0,
                rating.reviewCount(), reviews, services);
    }

    /**
     * Who the booking is with — so the review prompt can say whose work is being rated. Only the customer who made
     * the booking may ask (403 otherwise); 404 when the booking has no named person ("any master" bookings that were
     * never assigned, or a business that works without a team).
     */
    @Transactional(readOnly = true)
    public BookingWorkerResponse workerOfBooking(UUID bookingId, UUID userId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: " + bookingId));
        if (!booking.getUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not your booking");
        }
        Worker worker = catalog.workerOfBooking(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No person on this booking"));
        return new BookingWorkerResponse(worker.id(), worker.kind(), worker.displayName(), worker.photoUrl());
    }
}
