package com.zairo.factory.revenueengine;

import com.zairo.factory.revenueengine.RevenueEngineDtos.RevenueSummaryResponse;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * The write side ({@link #recordDecision}/{@link #recordNoAction}/{@link
 * #resolve}) and read side ({@link #summary}) of the outcome ledger every
 * {@link DecisionEngine} decision lands in — see {@link RevenueOutcome}'s
 * own doc comment for the two-write lifecycle.
 */
@Service
public class RevenueAttributionService {

    private final RevenueOutcomeRepository repository;

    public RevenueAttributionService(RevenueOutcomeRepository repository) {
        this.repository = repository;
    }

    /**
     * Idempotent by {@code (actionType, referenceId)} -- a duplicate call
     * for the same decision (e.g. a re-delivered event) returns the
     * existing row rather than violating the unique index or recording a
     * second pending outcome for the same real-world event.
     */
    RevenueOutcome recordDecision(DecisionContext context, StrategyDecision decision) {
        return repository.findByActionTypeAndTriggerRefId(decision.actionType(), context.referenceId())
                .orElseGet(() -> repository.save(new RevenueOutcome(UUID.randomUUID(), decision.actionType(),
                        context.providerId(), context.referenceId(), decision.expectedValue(), decision.currency(),
                        context.occurredAt())));
    }

    RevenueOutcome recordNoAction(DecisionContext context) {
        RevenueOutcome outcome = new RevenueOutcome(UUID.randomUUID(), ActionType.NO_ACTION, context.providerId(),
                context.referenceId(), BigDecimal.ZERO, null, context.occurredAt());
        outcome.resolve(BigDecimal.ZERO, null, false, context.occurredAt());
        return repository.save(outcome);
    }

    /**
     * Called by the strategy that executed once its real outcome is known —
     * e.g. {@code smartfill.SmartFillCampaignService} once a campaign is
     * BOOKED (recovered=true, actualRevenue = the real booking's price) or
     * EXPIRED (recovered=false, actualRevenue = zero). A no-op if no
     * matching pending decision exists (defensive — should not happen since
     * {@link #recordDecision} always runs first in the same flow).
     */
    public void resolve(ActionType actionType, UUID triggerRefId, BigDecimal actualRevenue, String currency,
            boolean recovered, Instant resolvedAt) {
        repository.findByActionTypeAndTriggerRefId(actionType, triggerRefId).ifPresent(outcome -> {
            outcome.resolve(actualRevenue, currency, recovered, resolvedAt);
            repository.save(outcome);
        });
    }

    /** provider-insights' "Revenue Recovered by ZAIRO" panel — see {@code ProviderInsightsController}. Lifetime, all decisions ever made. */
    public RevenueSummaryResponse summary(UUID providerId) {
        return summarize(repository.findByProviderId(providerId));
    }

    /**
     * The same summary, scoped to one reporting period — the Business
     * Analytics dashboard's "revenue recovered this month" tile, which
     * must move with the same date range as every other metric on the
     * page (see {@code providerinsights.BusinessAnalyticsService}).
     */
    public RevenueSummaryResponse summary(UUID providerId, Instant from, Instant to) {
        return summarize(repository.findByProviderIdAndDecidedAtBetween(providerId, from, to));
    }

    private RevenueSummaryResponse summarize(List<RevenueOutcome> outcomes) {
        long executed = outcomes.stream().filter(o -> o.getActionType() != ActionType.NO_ACTION).count();
        List<RevenueOutcome> recovered = outcomes.stream().filter(o -> Boolean.TRUE.equals(o.getRecovered())).toList();

        BigDecimal total = recovered.stream().map(RevenueOutcome::getActualRevenue)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        String currency = recovered.isEmpty() ? null : recovered.get(0).getCurrency();

        Map<ActionType, BigDecimal> byActionType = new EnumMap<>(ActionType.class);
        for (RevenueOutcome outcome : recovered) {
            byActionType.merge(outcome.getActionType(), outcome.getActualRevenue(), BigDecimal::add);
        }

        return new RevenueSummaryResponse(total, currency, executed, recovered.size(), byActionType);
    }
}
