package com.zairo.factory.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class PhoneNumberNormalizerTest {

    private final PhoneNumberNormalizer normalizer = new PhoneNumberNormalizer();

    @Test
    void normalizesAnE164NumberToItself() {
        assertThat(normalizer.normalize("+77001234567")).isEqualTo("+77001234567");
    }

    @Test
    void normalizesALocalKazakhstaniNumberWithNoCountryCode() {
        assertThat(normalizer.normalize("8 700 123 45 67")).isEqualTo("+77001234567");
    }

    /**
     * The exact abuse case CLAUDE.md task spec §6 calls out: "+7...", "8...",
     * spaces, and dashes must all collapse to the same identity, or a user
     * could end up with several accounts for the same real phone number.
     */
    @Test
    void treatsEveryTypedVariantOfTheSameNumberAsIdentical() {
        String canonical = normalizer.normalize("+77001234567");

        assertThat(normalizer.normalize("8 (700) 123-45-67")).isEqualTo(canonical);
        assertThat(normalizer.normalize("+7 700 123 45 67")).isEqualTo(canonical);
        assertThat(normalizer.normalize("77001234567")).isEqualTo(canonical);
    }

    @Test
    void acceptsAnExplicitForeignCountryCode() {
        assertThat(normalizer.normalize("+1 202 555 0173")).isEqualTo("+12025550173");
    }

    @Test
    void rejectsBlank() {
        assertThatThrownBy(() -> normalizer.normalize("")).isInstanceOf(InvalidPhoneNumberException.class);
        assertThatThrownBy(() -> normalizer.normalize(null)).isInstanceOf(InvalidPhoneNumberException.class);
    }

    @Test
    void rejectsGarbage() {
        assertThatThrownBy(() -> normalizer.normalize("not a phone number"))
                .isInstanceOf(InvalidPhoneNumberException.class);
    }

    @Test
    void rejectsATooShortNumber() {
        assertThatThrownBy(() -> normalizer.normalize("+7123")).isInstanceOf(InvalidPhoneNumberException.class);
    }
}
