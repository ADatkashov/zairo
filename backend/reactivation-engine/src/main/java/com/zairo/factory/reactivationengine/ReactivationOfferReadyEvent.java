package com.zairo.factory.reactivationengine;

import java.util.UUID;

/**
 * Published the moment a {@link ReactivationCampaign}'s win-back nudge goes
 * out -- carries its own denormalized {@code providerName}/{@code
 * serviceName} display strings so {@code notifications} doesn't need a
 * dependency on providers/services just to render an email, same shape as
 * {@code rebookengine.RebookOfferReadyEvent}.
 */
public record ReactivationOfferReadyEvent(UUID campaignId, UUID userId, UUID providerId, String providerName,
        String serviceName) {
}
