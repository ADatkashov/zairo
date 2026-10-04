package com.zairo.factory.loyalty;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import org.junit.jupiter.api.Test;

class BirthdayCalendarTest {

    @Test
    void nextBirthdayIsTodayWhenItFallsToday() {
        assertThat(BirthdayCalendar.nextBirthday(LocalDate.of(1995, 4, 23), LocalDate.of(2026, 4, 23)))
                .isEqualTo(LocalDate.of(2026, 4, 23));
    }

    @Test
    void nextBirthdayRollsToNextYearOncePassed() {
        assertThat(BirthdayCalendar.nextBirthday(LocalDate.of(1995, 4, 23), LocalDate.of(2026, 4, 24)))
                .isEqualTo(LocalDate.of(2027, 4, 23));
    }

    @Test
    void aLeapDayBirthdayIsCelebratedOnFeb28InANonLeapYear() {
        LocalDate born = LocalDate.of(2000, 2, 29);
        assertThat(BirthdayCalendar.birthdayIn(born, 2027)).isEqualTo(LocalDate.of(2027, 2, 28));
        assertThat(BirthdayCalendar.birthdayIn(born, 2028)).isEqualTo(LocalDate.of(2028, 2, 29));
        assertThat(BirthdayCalendar.nextBirthday(born, LocalDate.of(2026, 12, 1))).isEqualTo(LocalDate.of(2027, 2, 28));
    }

    @Test
    void dayRangeCoversFeb29OnFeb28OfANonLeapYearOnly() {
        assertThat(BirthdayCalendar.dayRangeForToday(LocalDate.of(2027, 2, 28))).containsExactly(28, 29);
        assertThat(BirthdayCalendar.dayRangeForToday(LocalDate.of(2028, 2, 28))).containsExactly(28, 28);
        assertThat(BirthdayCalendar.dayRangeForToday(LocalDate.of(2027, 7, 9))).containsExactly(9, 9);
    }
}
