package com.zairo.factory.revenueengine;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** The engine picks the applicable strategy with the highest expected-value x probability and runs only it. */
class DecisionEngineTest {

    private static final DecisionContext CANCELLED = new DecisionContext(DecisionTrigger.BOOKING_CANCELLED,
            UUID.randomUUID(), UUID.randomUUID(), Instant.parse("2026-10-12T10:00:00Z"));

    private RevenueAttributionService attribution;
    private final List<String> executed = new ArrayList<>();

    @BeforeEach
    void setUp() {
        attribution = mock(RevenueAttributionService.class);
        executed.clear();
    }

    /** A strategy fake with a fixed decision, recording whether it was executed. */
    private RevenueStrategy strategy(ActionType type, Set<DecisionTrigger> triggers, StrategyDecision decision) {
        return new RevenueStrategy() {
            @Override
            public ActionType actionType() {
                return type;
            }

            @Override
            public Set<DecisionTrigger> triggers() {
                return triggers;
            }

            @Override
            public StrategyDecision evaluate(DecisionContext context) {
                return decision;
            }

            @Override
            public void execute(DecisionContext context, StrategyDecision d) {
                executed.add(type.name());
            }
        };
    }

    private static StrategyDecision decision(ActionType type, String value, double probability) {
        return new StrategyDecision(type, true, new BigDecimal(value), "KZT", probability, "r");
    }

    @Test
    void theApplicableStrategyWithTheHighestPriorityWinsAndOnlyItRuns() {
        StrategyDecision smartFill = decision(ActionType.SMART_FILL, "8000", 0.25); // 2000
        StrategyDecision rebook = decision(ActionType.REBOOK, "5000", 0.5); // 2500
        DecisionEngine engine = new DecisionEngine(List.of(
                strategy(ActionType.SMART_FILL, Set.of(DecisionTrigger.BOOKING_CANCELLED), smartFill),
                strategy(ActionType.REBOOK, Set.of(DecisionTrigger.BOOKING_CANCELLED), rebook)), attribution);

        engine.decideAndExecute(CANCELLED);

        assertThat(executed).containsExactly("REBOOK");
        verify(attribution).recordDecision(CANCELLED, rebook);
        verify(attribution, never()).recordNoAction(any());
    }

    @Test
    void aTieKeepsTheFirstStrategyInTheList() {
        StrategyDecision a = decision(ActionType.SMART_FILL, "1000", 0.5);
        StrategyDecision b = decision(ActionType.REBOOK, "500", 1.0);
        DecisionEngine engine = new DecisionEngine(List.of(
                strategy(ActionType.SMART_FILL, Set.of(DecisionTrigger.BOOKING_CANCELLED), a),
                strategy(ActionType.REBOOK, Set.of(DecisionTrigger.BOOKING_CANCELLED), b)), attribution);

        engine.decideAndExecute(CANCELLED);

        assertThat(executed).containsExactly("SMART_FILL");
    }

    @Test
    void strategiesNotSubscribedToTheTriggerAreSkippedEvenIfTheyWouldScoreHigher() {
        StrategyDecision low = decision(ActionType.SMART_FILL, "100", 0.1);
        StrategyDecision highButWrongTrigger = decision(ActionType.REBOOK, "999999", 1.0);
        DecisionEngine engine = new DecisionEngine(List.of(
                strategy(ActionType.SMART_FILL, Set.of(DecisionTrigger.BOOKING_CANCELLED), low),
                strategy(ActionType.REBOOK, Set.of(DecisionTrigger.BOOKING_COMPLETED), highButWrongTrigger)),
                attribution);

        engine.decideAndExecute(CANCELLED);

        assertThat(executed).containsExactly("SMART_FILL");
    }

    @Test
    void notApplicableStrategiesAreSkippedEvenIfSubscribed() {
        DecisionEngine engine = new DecisionEngine(List.of(strategy(ActionType.SMART_FILL,
                Set.of(DecisionTrigger.BOOKING_CANCELLED),
                StrategyDecision.notApplicable(ActionType.SMART_FILL, "no candidates"))), attribution);

        engine.decideAndExecute(CANCELLED);

        assertThat(executed).isEmpty();
        verify(attribution).recordNoAction(CANCELLED);
        verify(attribution, never()).recordDecision(any(), any());
    }

    @Test
    void noStrategiesAtAllRecordsNoAction() {
        DecisionEngine engine = new DecisionEngine(List.of(), attribution);

        engine.decideAndExecute(CANCELLED);

        verify(attribution).recordNoAction(CANCELLED);
        assertThat(executed).isEmpty();
    }

    @Test
    void theDecisionIsRecordedBeforeTheStrategyIsExecuted() {
        StrategyDecision d = decision(ActionType.SMART_FILL, "1000", 1.0);
        List<String> order = new ArrayList<>();
        org.mockito.Mockito.doAnswer(inv -> {
            order.add("record");
            return null;
        }).when(attribution).recordDecision(any(), any());
        RevenueStrategy s = new RevenueStrategy() {
            @Override
            public ActionType actionType() {
                return ActionType.SMART_FILL;
            }

            @Override
            public Set<DecisionTrigger> triggers() {
                return Set.of(DecisionTrigger.BOOKING_CANCELLED);
            }

            @Override
            public StrategyDecision evaluate(DecisionContext context) {
                return d;
            }

            @Override
            public void execute(DecisionContext context, StrategyDecision decision) {
                order.add("execute");
            }
        };

        new DecisionEngine(List.of(s), attribution).decideAndExecute(CANCELLED);

        assertThat(order).containsExactly("record", "execute");
    }
}
