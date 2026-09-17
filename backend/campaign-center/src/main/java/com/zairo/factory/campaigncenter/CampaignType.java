package com.zairo.factory.campaigncenter;

/**
 * Which of the three existing campaign engines a campaign belongs to --
 * used as a path variable ({@code /campaigns/{type}/{campaignId}}) so every
 * detail/timeline/action endpoint knows which engine's repository and
 * service to resolve, without a shared primary-key space across the three
 * underlying tables. New Revenue Engine strategies (Smart Promotion,
 * No-show Prevention, ...) add a constant here plus one more branch in
 * {@link CampaignCenterService} once they exist -- see this module's
 * package-info for why there's no shared "Campaign" table to extend
 * instead.
 */
public enum CampaignType {
    SMART_FILL,
    REBOOK,
    REACTIVATION,
}
