package com.zairo.factory.rebookengine;

import java.util.UUID;

/**
 * Published the moment a {@link RebookCampaign}'s nudge goes out -- carries
 * its own denormalized {@code providerName}/{@code serviceName} display
 * strings so {@code notifications} doesn't need a dependency on providers/
 * services just to render an email, same shape as {@code
 * smartfill.SmartFillOfferReadyEvent}.
 */
public record RebookOfferReadyEvent(UUID campaignId, UUID userId, UUID providerId, String providerName,
        String serviceName) {
}
