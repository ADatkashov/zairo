package com.zairo.factory.staff;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Plain unit test of the Staff aggregate -- no Spring context, no database. */
class StaffTest {

    private static final Instant T0 = Instant.parse("2026-10-12T10:00:00Z");

    private static Staff staff(boolean active) {
        return new Staff(UUID.randomUUID(), UUID.randomUUID(), "Aigerim", "bio", "https://img/1.png", active, T0);
    }

    @Test
    void newStaffHasNoLinkedUserAccount() {
        Staff s = staff(true);

        assertThat(s.getUserId()).isNull();
        assertThat(s.isActive()).isTrue();
        assertThat(s.getDisplayName()).isEqualTo("Aigerim");
        assertThat(s.getCreatedAt()).isEqualTo(T0);
    }

    @Test
    void withUserIdLinksTheAccountAndReturnsTheSameStaff() {
        Staff s = staff(true);
        UUID user = UUID.randomUUID();

        Staff linked = s.withUserId(user);

        assertThat(linked).isSameAs(s);
        assertThat(s.getUserId()).isEqualTo(user);
    }

    @Test
    void deactivateAndReactivateToggleTheFlag() {
        Staff s = staff(true);

        s.deactivate();
        assertThat(s.isActive()).isFalse();

        s.reactivate();
        assertThat(s.isActive()).isTrue();
    }

    @Test
    void deactivatingTwiceStaysInactive() {
        Staff s = staff(false);

        s.deactivate();

        assertThat(s.isActive()).isFalse();
    }

    @Test
    void updatePhotoReplacesOnlyThePhoto() {
        Staff s = staff(true);

        s.updatePhoto("https://img/2.png");

        assertThat(s.getPhotoUrl()).isEqualTo("https://img/2.png");
        assertThat(s.getDisplayName()).isEqualTo("Aigerim");
        assertThat(s.getBio()).isEqualTo("bio");
    }
}
