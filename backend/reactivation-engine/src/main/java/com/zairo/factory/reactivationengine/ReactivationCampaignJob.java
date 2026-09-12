package com.zairo.factory.reactivationengine;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * The time-triggered half of a campaign's lifecycle: expires any SENT
 * campaign whose follow-up window has closed unbooked. (Sending itself
 * isn't scheduled -- {@link ReactivationCampaignService#startCampaignForInactiveCustomer}
 * sends immediately, since {@link ReactivationCandidateDiscoveryJob} only
 * ever finds customers already overdue.) Same "@Scheduled sweep, one
 * @Transactional call per row, catch and log rather than let one failure
 * kill the whole pass" shape as {@code rebookengine.RebookCampaignJob} --
 * justified the same way per ADR-0005.
 *
 * <p>{@link OptimisticLockingFailureException} here specifically means a
 * concurrent run (a second instance's sweep, or this exact campaign getting
 * closed out by {@link ReactivationOutcomeListener} at the same moment)
 * beat this one to the row -- not a real failure, so it's swallowed at
 * debug level rather than logged as an error like a genuine one is.
 */
@Component
class ReactivationCampaignJob {

    private static final Logger log = LoggerFactory.getLogger(ReactivationCampaignJob.class);

    private final ReactivationCampaignRepository campaignRepository;
    private final ReactivationCampaignService campaignService;
    private final Clock clock;

    ReactivationCampaignJob(ReactivationCampaignRepository campaignRepository,
            ReactivationCampaignService campaignService, Clock clock) {
        this.campaignRepository = campaignRepository;
        this.campaignService = campaignService;
        this.clock = clock;
    }

    @Scheduled(fixedDelay = 3_600_000)
    void expireStaleCampaigns() {
        Instant now = clock.instant();
        List<ReactivationCampaign> stale = campaignRepository
                .findByStatusAndExpiresAtLessThanEqual(ReactivationCampaignStatus.SENT, now);
        for (ReactivationCampaign campaign : stale) {
            try {
                campaignService.expireCampaign(campaign.getId(), now);
            } catch (OptimisticLockingFailureException e) {
                log.debug("Reactivation campaign {} was already closed concurrently, skipping", campaign.getId());
            } catch (RuntimeException e) {
                log.error("Failed to expire Reactivation campaign {}: {}", campaign.getId(), e.getMessage(), e);
            }
        }
    }
}
