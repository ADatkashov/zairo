package com.zairo.factory.revenueengine;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class StrategyDecisionTest {

    @Test
    void priorityIsExpectedValueTimesProbability() {
        StrategyDecision d = new StrategyDecision(ActionType.SMART_FILL, true, new BigDecimal("8000"), "KZT", 0.25,
                "likely to fill");

        assertThat(d.priorityScore()).isEqualByComparingTo("2000");
    }

    @Test
    void zeroProbabilityMeansZeroPriorityWhateverTheValue() {
        StrategyDecision d = new StrategyDecision(ActionType.REBOOK, true, new BigDecimal("999999"), "KZT", 0.0, "");

        assertThat(d.priorityScore()).isEqualByComparingTo("0");
    }

    @Test
    void notApplicableDecisionHasNoValueAndNoPriority() {
        StrategyDecision d = StrategyDecision.notApplicable(ActionType.GAP_FILL, "slot too soon");

        assertThat(d.applicable()).isFalse();
        assertThat(d.actionType()).isEqualTo(ActionType.GAP_FILL);
        assertThat(d.rationale()).isEqualTo("slot too soon");
        assertThat(d.expectedValue()).isEqualByComparingTo("0");
        assertThat(d.priorityScore()).isEqualByComparingTo("0");
        assertThat(d.currency()).isNull();
    }
}
