package com.zairo.factory.city;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class CityTest {

    private static City city(Integer radius, Boolean active) {
        return new City("almaty", "Алматы", "Алматы", "KZ", "Asia/Almaty", "KZT", new BigDecimal("43.238"),
                new BigDecimal("76.945"), radius, active);
    }

    @Test
    void searchRadiusDefaultsToFiftyKilometres() {
        assertThat(city(null, true).getDefaultSearchRadiusKm()).isEqualTo(50);
    }

    @Test
    void anExplicitSearchRadiusIsKept() {
        assertThat(city(20, true).getDefaultSearchRadiusKm()).isEqualTo(20);
    }

    @Test
    void aCityIsActiveByDefault() {
        assertThat(city(null, null).getActive()).isTrue();
    }

    @Test
    void anExplicitlyInactiveCityStaysInactive() {
        assertThat(city(null, false).getActive()).isFalse();
    }

    @Test
    void updateReplacesEditableFieldsButNotTheCode() {
        City c = city(30, true);

        c.update("Алматы (обл.)", "Алматы", "Asia/Almaty", "KZT", new BigDecimal("43.3"), new BigDecimal("77.0"),
                null, false);

        assertThat(c.getName()).isEqualTo("Алматы (обл.)");
        assertThat(c.getCode()).isEqualTo("almaty");
        assertThat(c.getCountryCode()).isEqualTo("KZ");
        assertThat(c.getLatitude()).isEqualByComparingTo("43.3");
        assertThat(c.getDefaultSearchRadiusKm()).isEqualTo(50);
        assertThat(c.getActive()).isFalse();
    }

    @Test
    void updateRefreshesTheModificationTimeOnly() {
        City c = city(30, true);
        var created = c.getCreatedAt();

        c.update("A", "A", "Asia/Almaty", "KZT", BigDecimal.ONE, BigDecimal.ONE, 10, true);

        assertThat(c.getCreatedAt()).isEqualTo(created);
        assertThat(c.getUpdatedAt()).isAfterOrEqualTo(created);
    }
}
