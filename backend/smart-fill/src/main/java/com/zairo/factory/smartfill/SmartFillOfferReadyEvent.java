package com.zairo.factory.smartfill;

import java.time.Instant;
import java.util.UUID;

/**
 * Published once a {@link CandidateOffer} is marked NOTIFIED -- see ADR-0002
 * (in-process domain events instead of Kafka). {@code notifications} is the
 * only consumer (turns this into a real email + in-app notification); this
 * module never calls {@code NotificationService} directly, same
 * publisher-doesn't-depend-on-the-subscriber pattern every other domain
 * event in this codebase follows. Carries its own denormalized display
 * strings (provider/service/employee name) rather than just ids so
 * {@code notifications} doesn't need a dependency on providers/services/
 * staff just to resolve them.
 */
public record SmartFillOfferReadyEvent(
        UUID offerId,
        UUID campaignId,
        UUID userId,
        UUID providerId,
        String providerName,
        String serviceName,
        /** Null if the slot wasn't tied to one specific employee, or that employee isn't in the generic staff directory. */
        String employeeName,
        Instant slotStartsAt,
        Instant slotEndsAt) {
}
