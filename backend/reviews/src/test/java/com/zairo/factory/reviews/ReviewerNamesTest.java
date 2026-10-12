package com.zairo.factory.reviews;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class ReviewerNamesTest {

    @Test
    void abbreviatesToFirstNameAndLastInitial() {
        assertThat(ReviewerNames.abbreviate("Aisha Karimova")).isEqualTo("Aisha K.");
        assertThat(ReviewerNames.abbreviate("  Анна  петрова ")).isEqualTo("Анна П.");
        assertThat(ReviewerNames.abbreviate("Mary Jane Watson")).isEqualTo("Mary W.");
    }

    @Test
    void singleNameIsKeptAsIs() {
        assertThat(ReviewerNames.abbreviate("Aisha")).isEqualTo("Aisha");
    }

    @Test
    void neverEchoesEmailsOrUnusableNames() {
        assertThat(ReviewerNames.abbreviate("aisha@example.com")).isEqualTo("Customer");
        assertThat(ReviewerNames.abbreviate("Aisha a@b.c")).isEqualTo("Customer");
        assertThat(ReviewerNames.abbreviate("   ")).isEqualTo("Customer");
        assertThat(ReviewerNames.abbreviate(null)).isEqualTo("Customer");
        assertThat(ReviewerNames.abbreviate("+7 701 000")).isEqualTo("Customer");
    }
}
