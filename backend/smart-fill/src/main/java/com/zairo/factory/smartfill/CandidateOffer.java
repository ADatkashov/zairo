package com.zairo.factory.smartfill;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * One candidate's place in one {@link SmartFillCampaign} -- its score, why
 * it earned that score ({@link #matchedFactors}, a plain comma-joined list
 * rather than a child table since it's write-once and only ever read back
 * whole), which stage batch it belongs to, and whether it ever turned into
 * an actual booking.
 */
@Entity
@Table(name = "smart_fill_candidate_offer")
public class CandidateOffer {

    @Id
    private UUID id;

    @Column(name = "campaign_id", nullable = false)
    private UUID campaignId;

    /**
     * Denormalized from the owning {@link SmartFillCampaign} -- {@link
     * NotificationPolicy}'s per-business cooldown/limit checks need "has
     * this user been offered anything from this provider recently" without
     * a join for every candidate of every new campaign.
     */
    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false)
    private int score;

    @Column(nullable = false)
    private int rank;

    @Column(nullable = false)
    private int stage;

    @Column(name = "matched_factors", nullable = false)
    private String matchedFactors;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private CandidateOfferStatus status;

    @Column(name = "notified_at")
    private Instant notifiedAt;

    @Column(name = "responded_at")
    private Instant respondedAt;

    @Column(name = "booking_id")
    private UUID bookingId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Version
    private long version;

    protected CandidateOffer() {
    }

    public CandidateOffer(UUID id, UUID campaignId, UUID providerId, UUID userId, int score, int rank, int stage,
            Set<ScoringFactor> matchedFactors, Instant createdAt) {
        this.id = id;
        this.campaignId = campaignId;
        this.providerId = providerId;
        this.userId = userId;
        this.score = score;
        this.rank = rank;
        this.stage = stage;
        this.matchedFactors = matchedFactors.stream().map(Enum::name).collect(Collectors.joining(","));
        this.status = CandidateOfferStatus.PENDING;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getCampaignId() {
        return campaignId;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public UUID getUserId() {
        return userId;
    }

    public int getScore() {
        return score;
    }

    public int getRank() {
        return rank;
    }

    public int getStage() {
        return stage;
    }

    public String getMatchedFactors() {
        return matchedFactors;
    }

    public CandidateOfferStatus getStatus() {
        return status;
    }

    public Instant getNotifiedAt() {
        return notifiedAt;
    }

    public Instant getRespondedAt() {
        return respondedAt;
    }

    public UUID getBookingId() {
        return bookingId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    void markNotified(Instant now) {
        this.status = CandidateOfferStatus.NOTIFIED;
        this.notifiedAt = now;
    }

    void markViewed() {
        if (this.status == CandidateOfferStatus.NOTIFIED) {
            this.status = CandidateOfferStatus.VIEWED;
        }
    }

    void markAccepted(UUID bookingId, Instant now) {
        this.status = CandidateOfferStatus.ACCEPTED;
        this.bookingId = bookingId;
        this.respondedAt = now;
    }

    /** The slot went to someone else (a different candidate, or a non-candidate entirely). */
    void markCancelled() {
        if (this.status == CandidateOfferStatus.PENDING || this.status == CandidateOfferStatus.NOTIFIED
                || this.status == CandidateOfferStatus.VIEWED) {
            this.status = CandidateOfferStatus.CANCELLED;
        }
    }

    void markExpired() {
        if (this.status == CandidateOfferStatus.PENDING || this.status == CandidateOfferStatus.NOTIFIED
                || this.status == CandidateOfferStatus.VIEWED) {
            this.status = CandidateOfferStatus.EXPIRED;
        }
    }
}
