package com.zairo.factory.rebookengine;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * The time-triggered side of a campaign's lifecycle: sends the nudge for any
 * CREATED campaign whose predicted next-visit date has arrived, and expires
 * any OFFERED campaign whose follow-up window has closed unbooked. Same
 * "@Scheduled sweep, one @Transactional call per row, catch and log rather
 * than let one failure kill the whole pass" shape as {@code
 * smartfill.SmartFillCampaignJob} -- justified the same way per ADR-0005: a
 * nudge timed to a customer's own visit cadence, potentially weeks out,
 * can't be an on-demand HTTP call. Runs hourly rather than SmartFillCampaignJob's
 * one-minute cadence since this operates on day-granularity dates, not
 * minutes-away slot contention.
 *
 * <p>{@link OptimisticLockingFailureException} here specifically means a
 * concurrent run (a second instance's sweep, or this exact campaign getting
 * closed out by {@link RebookOutcomeListener} at the same moment) beat this
 * one to the row -- not a real failure, so it's swallowed at debug level
 * rather than logged as an error like a genuine one is.
 */
@Component
class RebookCampaignJob {

    private static final Logger log = LoggerFactory.getLogger(RebookCampaignJob.class);

    private final RebookCampaignRepository campaignRepository;
    private final RebookCampaignService campaignService;
    private final Clock clock;

    RebookCampaignJob(RebookCampaignRepository campaignRepository, RebookCampaignService campaignService,
            Clock clock) {
        this.campaignRepository = campaignRepository;
        this.campaignService = campaignService;
        this.clock = clock;
    }

    @Scheduled(fixedDelay = 3_600_000)
    void sendDueOffers() {
        Instant now = clock.instant();
        List<RebookCampaign> due = campaignRepository.findByStatusAndDueAtLessThanEqual(RebookCampaignStatus.CREATED,
                now);
        for (RebookCampaign campaign : due) {
            try {
                campaignService.sendDueOffer(campaign.getId(), now);
            } catch (OptimisticLockingFailureException e) {
                log.debug("Rebook campaign {} was already advanced/closed concurrently, skipping", campaign.getId());
            } catch (RuntimeException e) {
                log.error("Failed to send Rebook offer for campaign {}: {}", campaign.getId(), e.getMessage(), e);
            }
        }
    }

    @Scheduled(fixedDelay = 3_600_000)
    void expireStaleCampaigns() {
        Instant now = clock.instant();
        List<RebookCampaign> stale = campaignRepository
                .findByStatusAndExpiresAtLessThanEqual(RebookCampaignStatus.OFFERED, now);
        for (RebookCampaign campaign : stale) {
            try {
                campaignService.expireCampaign(campaign.getId(), now);
            } catch (OptimisticLockingFailureException e) {
                log.debug("Rebook campaign {} was already closed concurrently, skipping", campaign.getId());
            } catch (RuntimeException e) {
                log.error("Failed to expire Rebook campaign {}: {}", campaign.getId(), e.getMessage(), e);
            }
        }
    }
}
