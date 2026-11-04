package com.zairo.factory.providers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

class WorkingHoursTest {

    @Test
    void formatsInWeekOrderAndParsesBack() {
        Map<String, String> hours = Map.of("sat", "10:00-16:00", "mon", "09:00-20:00");
        String stored = WorkingHours.format(hours);
        assertThat(stored).isEqualTo("mon=09:00-20:00;sat=10:00-16:00");
        assertThat(WorkingHours.parse(stored)).isEqualTo(hours);
    }

    @Test
    void emptyOrNullFormatsToNullAndParsesToEmpty() {
        assertThat(WorkingHours.format(null)).isNull();
        assertThat(WorkingHours.format(Map.of())).isNull();
        assertThat(WorkingHours.parse(null)).isEmpty();
        assertThat(WorkingHours.parse(" ")).isEmpty();
    }

    @Test
    void parseSkipsMalformedPieces() {
        assertThat(WorkingHours.parse("mon=09:00-20:00;bogus;xyz=09:00-10:00;tue=9-10"))
                .containsOnlyKeys("mon");
    }

    @Test
    void validateAcceptsGoodAndNull() {
        WorkingHours.validate(null);
        WorkingHours.validate(Map.of("sun", "00:00-23:59"));
    }

    @Test
    void validateRejectsBadDayRangeAndOrder() {
        assertThatThrownBy(() -> WorkingHours.validate(Map.of("funday", "09:00-10:00")))
                .isInstanceOf(ResponseStatusException.class);
        assertThatThrownBy(() -> WorkingHours.validate(Map.of("mon", "9-10")))
                .isInstanceOf(ResponseStatusException.class);
        assertThatThrownBy(() -> WorkingHours.validate(Map.of("mon", "10:00-10:00")))
                .isInstanceOf(ResponseStatusException.class);
        assertThatThrownBy(() -> WorkingHours.validate(Map.of("mon", "24:00-25:00")))
                .isInstanceOf(ResponseStatusException.class);
    }
}
