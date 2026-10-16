package com.zairo.factory.reviews;

import com.zairo.factory.platformadmin.PlatformAuditLogService;
import com.zairo.factory.reviews.ReviewDtos.ModerationReviewResponse;
import java.time.Instant;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * The platform's side of review moderation: the queue of reports and the decisions on them. Every decision goes to
 * the platform audit log.
 */
@Service
public class ReviewModerationService {

    static final String TARGET = "REVIEW";

    private final ReviewRepository reviewRepository;
    private final PlatformAuditLogService auditLogService;

    public ReviewModerationService(ReviewRepository reviewRepository, PlatformAuditLogService auditLogService) {
        this.reviewRepository = reviewRepository;
        this.auditLogService = auditLogService;
    }

    /** {@code status}: OPEN (waiting), HIDDEN or DISMISSED; anything else is a 400. */
    @Transactional(readOnly = true)
    public Page<ModerationReviewResponse> queue(String status, Pageable pageable) {
        String normalized = status == null ? "OPEN" : status.toUpperCase(java.util.Locale.ROOT);
        if (!normalized.equals("OPEN") && !normalized.equals("HIDDEN") && !normalized.equals("DISMISSED")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "status must be OPEN, HIDDEN or DISMISSED");
        }
        return reviewRepository.findForModeration(normalized, pageable).map(row -> new ModerationReviewResponse(
                row.getId(), row.getBookingId(), row.getProviderId(), row.getProviderName(), row.getRating(),
                row.getComment(), row.getCreatedAt(), row.getBusinessReply(), row.getReportReason(),
                row.getReportedAt(), row.getHiddenAt() != null ? "HIDDEN"
                        : row.getReportResolvedAt() == null ? "OPEN" : "DISMISSED",
                row.getHiddenAt(), row.getHiddenReason()));
    }

    /** Hides the review from every rating and list; closes its report. Hiding twice is a no-op. */
    @Transactional
    public void hide(UUID actorId, String actorEmail, UUID reviewId, String reason) {
        Review review = find(reviewId);
        if (review.isHidden()) {
            return;
        }
        review.hide(blankToNull(reason), Instant.now());
        reviewRepository.save(review);
        auditLogService.record(actorId, actorEmail, "REVIEW_HIDDEN", TARGET, reviewId, "VISIBLE", "HIDDEN",
                blankToNull(reason));
    }

    /** Puts a hidden review back. Restoring a visible review is a no-op. */
    @Transactional
    public void restore(UUID actorId, String actorEmail, UUID reviewId, String reason) {
        Review review = find(reviewId);
        if (!review.isHidden()) {
            return;
        }
        review.restore();
        reviewRepository.save(review);
        auditLogService.record(actorId, actorEmail, "REVIEW_RESTORED", TARGET, reviewId, "HIDDEN", "VISIBLE",
                blankToNull(reason));
    }

    /** The review stays: the open report is closed (and cannot be filed again). 409 when there is nothing open. */
    @Transactional
    public void dismiss(UUID actorId, String actorEmail, UUID reviewId, String reason) {
        Review review = find(reviewId);
        if (!review.wasReported() || review.getReportResolvedAt() != null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "No open report on this review: " + reviewId);
        }
        review.dismissReport(Instant.now());
        reviewRepository.save(review);
        auditLogService.record(actorId, actorEmail, "REVIEW_REPORT_DISMISSED", TARGET, reviewId, "OPEN", "DISMISSED",
                blankToNull(reason));
    }

    private Review find(UUID reviewId) {
        return reviewRepository.findById(reviewId).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Review not found: " + reviewId));
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
