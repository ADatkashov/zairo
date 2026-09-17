package com.zairo.factory.smartfill;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * The time-triggered side of a campaign's lifecycle: advances any NOTIFYING
 * campaign whose {@code nextStageAt} has passed (sends the next batch, or
 * expires it if there's no next batch/the slot's start time has passed/the
 * campaign's hard duration ceiling is up). Runs every minute, same cadence
 * and same "@Scheduled sweep, one @Transactional call per row, catch and log
 * rather than let one failure kill the whole pass" shape as {@code
 * booking.BookingPaymentTimeoutJob} -- justified the same way per ADR-0005:
 * a staged rollout with a real wall-clock delay between stages can't be an
 * on-demand HTTP call, since nothing would trigger stage 2 if the customer
 * who'd trigger it never comes back.
 *
 * <p>{@link OptimisticLockingFailureException} here specifically means a
 * concurrent run (a second instance's sweep, or this exact campaign getting
 * closed out by {@link SlotBookedSmartFillListener} at the same moment) beat
 * this one to the row -- not a real failure, so it's swallowed at debug
 * level rather than logged as an error like a genuine one is.
 */
@Component
class SmartFillCampaignJob {

    private static final Logger log = LoggerFactory.getLogger(SmartFillCampaignJob.class);

    private final SmartFillCampaignRepository campaignRepository;
    private final SmartFillCampaignService campaignService;
    private final Clock clock;

    SmartFillCampaignJob(SmartFillCampaignRepository campaignRepository, SmartFillCampaignService campaignService,
            Clock clock) {
        this.campaignRepository = campaignRepository;
        this.campaignService = campaignService;
        this.clock = clock;
    }

    @Scheduled(fixedDelay = 60_000)
    void advanceDueCampaigns() {
        Instant now = clock.instant();
        List<SmartFillCampaign> due = campaignRepository
                .findByStatusAndNextStageAtLessThanEqual(SmartFillCampaignStatus.NOTIFYING, now);
        for (SmartFillCampaign campaign : due) {
            try {
                campaignService.advanceDueCampaign(campaign.getId(), now);
            } catch (OptimisticLockingFailureException e) {
                log.debug("Smart Fill campaign {} was already advanced/closed concurrently, skipping", campaign.getId());
            } catch (RuntimeException e) {
                log.error("Failed to advance Smart Fill campaign {}: {}", campaign.getId(), e.getMessage(), e);
            }
        }
    }
}
