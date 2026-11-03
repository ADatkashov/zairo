package com.zairo.factory.providerinsights;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.customerintelligence.CustomerProviderProfile;
import com.zairo.factory.customerintelligence.CustomerProviderProfileRepository;
import com.zairo.factory.providerinsights.BusinessBackupDtos.BackupResponse;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.staff.Staff;
import com.zairo.factory.staff.StaffRepository;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/** The copy lists every booking with who is coming and how to reach them, plus the customer book and the price list. */
class BusinessBackupServiceTest {

    private static final Instant NOW = Instant.parse("2026-10-25T10:00:00Z");
    private static final UUID PROVIDER = UUID.randomUUID();

    private BookingRepository bookings;
    private AvailabilitySlotRepository slots;
    private ServiceOfferingRepository services;
    private StaffRepository staff;
    private UserRepository users;
    private CustomerProviderProfileRepository profiles;
    private BusinessBackupService service;

    @BeforeEach
    void setUp() {
        bookings = mock(BookingRepository.class);
        slots = mock(AvailabilitySlotRepository.class);
        services = mock(ServiceOfferingRepository.class);
        staff = mock(StaffRepository.class);
        users = mock(UserRepository.class);
        profiles = mock(CustomerProviderProfileRepository.class);
        service = new BusinessBackupService(bookings, slots, services, staff, users, profiles,
                Clock.fixed(NOW, ZoneOffset.UTC));
        when(bookings.findByProviderIdAndSlotStartsAtBetween(eq(PROVIDER), any(), any())).thenReturn(List.of());
        when(slots.findAllById(any())).thenReturn(List.of());
        when(services.findByProviderId(PROVIDER)).thenReturn(List.of());
        when(staff.findByProviderId(PROVIDER)).thenReturn(List.of());
        when(users.findAllById(any())).thenReturn(List.of());
        when(profiles.findByProviderId(PROVIDER)).thenReturn(List.of());
    }

    private static Booking booking(UUID user, UUID slot, UUID serviceId, String price) {
        Booking b = mock(Booking.class);
        when(b.getId()).thenReturn(UUID.randomUUID());
        when(b.getUserId()).thenReturn(user);
        when(b.getAvailabilitySlotId()).thenReturn(slot);
        when(b.getServiceId()).thenReturn(serviceId);
        when(b.getStatus()).thenReturn(BookingStatus.CONFIRMED);
        when(b.getTotalPrice()).thenReturn(new BigDecimal(price));
        when(b.getCurrency()).thenReturn("KZT");
        return b;
    }

    private static AvailabilitySlot slot(UUID id, String starts, UUID employee) {
        AvailabilitySlot s = mock(AvailabilitySlot.class);
        when(s.getId()).thenReturn(id);
        when(s.getStartsAt()).thenReturn(Instant.parse(starts));
        when(s.getEndsAt()).thenReturn(Instant.parse(starts).plusSeconds(3600));
        when(s.getEmployeeId()).thenReturn(employee);
        return s;
    }

    private static User user(UUID id, String name, String phone, String email) {
        User u = mock(User.class);
        when(u.getId()).thenReturn(id);
        when(u.getDisplayName()).thenReturn(name);
        when(u.getPhone()).thenReturn(phone);
        when(u.getEmail()).thenReturn(email);
        return u;
    }

    @Test
    void bookingsComeOldestFirstWithCustomerContactServiceAndMaster() {
        UUID ana = UUID.randomUUID();
        UUID bek = UUID.randomUUID();
        UUID slotLate = UUID.randomUUID();
        UUID slotEarly = UUID.randomUUID();
        UUID haircut = UUID.randomUUID();
        UUID master = UUID.randomUUID();
        Staff aigerim = mock(Staff.class);
        when(aigerim.getId()).thenReturn(master);
        when(aigerim.getDisplayName()).thenReturn("Aigerim");
        ServiceOffering offering = mock(ServiceOffering.class);
        when(offering.getId()).thenReturn(haircut);
        when(offering.getTitle()).thenReturn("Haircut");

        List<Booking> bookingList = List.of(booking(ana, slotLate, haircut, "9000"),
                booking(bek, slotEarly, haircut, "8000"));
        List<AvailabilitySlot> slotList = List.of(slot(slotLate, "2026-10-30T12:00:00Z", master),
                slot(slotEarly, "2026-10-26T09:00:00Z", null));
        List<User> userList = List.of(user(ana, "Ana", "+77001112233", "ana@x.kz"), user(bek, "Bek", null, "bek@x.kz"));
        when(bookings.findByProviderIdAndSlotStartsAtBetween(eq(PROVIDER), any(), any())).thenReturn(bookingList);
        when(slots.findAllById(any())).thenReturn(slotList);
        when(services.findByProviderId(PROVIDER)).thenReturn(List.of(offering));
        when(staff.findByProviderId(PROVIDER)).thenReturn(List.of(aigerim));
        when(users.findAllById(any())).thenReturn(userList);

        BackupResponse copy = service.backup(PROVIDER, null, null);

        assertThat(copy.bookings()).hasSize(2);
        var first = copy.bookings().get(0);
        assertThat(first.startsAt()).isEqualTo(Instant.parse("2026-10-26T09:00:00Z"));
        assertThat(first.customerName()).isEqualTo("Bek");
        assertThat(first.customerPhone()).isNull();
        assertThat(first.staffName()).isNull();
        var second = copy.bookings().get(1);
        assertThat(second.customerName()).isEqualTo("Ana");
        assertThat(second.customerPhone()).isEqualTo("+77001112233");
        assertThat(second.customerEmail()).isEqualTo("ana@x.kz");
        assertThat(second.staffName()).isEqualTo("Aigerim");
        assertThat(second.serviceTitle()).isEqualTo("Haircut");
        assertThat(second.status()).isEqualTo("CONFIRMED");
        assertThat(second.totalPrice()).isEqualByComparingTo("9000");
    }

    @Test
    void aBookingWhoseCustomerIsGoneStillAppearsWithoutContact() {
        UUID slotId = UUID.randomUUID();
        List<Booking> bookingList = List.of(booking(UUID.randomUUID(), slotId, UUID.randomUUID(), "1"));
        List<AvailabilitySlot> slotList = List.of(slot(slotId, "2026-10-26T09:00:00Z", null));
        when(bookings.findByProviderIdAndSlotStartsAtBetween(eq(PROVIDER), any(), any())).thenReturn(bookingList);
        when(slots.findAllById(any())).thenReturn(slotList);

        var row = service.backup(PROVIDER, null, null).bookings().get(0);

        assertThat(row.customerName()).isNull();
        assertThat(row.customerPhone()).isNull();
        assertThat(row.serviceTitle()).isNull();
    }

    @Test
    void aBookingWithoutItsSlotIsLeftOut() {
        List<Booking> bookingList = List.of(booking(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), "1"));
        when(bookings.findByProviderIdAndSlotStartsAtBetween(eq(PROVIDER), any(), any())).thenReturn(bookingList);

        assertThat(service.backup(PROVIDER, null, null).bookings()).isEmpty();
    }

    @Test
    void customersComeMostRecentVisitFirstWithContactAndTotals() {
        UUID ana = UUID.randomUUID();
        UUID bek = UUID.randomUUID();
        UUID never = UUID.randomUUID();
        List<CustomerProviderProfile> profileList = List.of(profile(never, null, 0, "0", 0),
                profile(ana, "2026-09-01T10:00:00Z", 3, "27000", 1), profile(bek, "2026-10-01T10:00:00Z", 5, "45000", 0));
        List<User> userList = List.of(user(ana, "Ana", "+77001112233", "ana@x.kz"),
                user(bek, "Bek", "+77002223344", null));
        when(profiles.findByProviderId(PROVIDER)).thenReturn(profileList);
        when(users.findAllById(any())).thenReturn(userList);

        var customers = service.backup(PROVIDER, null, null).customers();

        assertThat(customers).extracting(c -> c.userId()).containsExactly(bek, ana, never);
        assertThat(customers.get(0).phone()).isEqualTo("+77002223344");
        assertThat(customers.get(0).totalSpent()).isEqualByComparingTo("45000");
        assertThat(customers.get(1).noShows()).isEqualTo(1);
        assertThat(customers.get(2).name()).isNull();
    }

    private static CustomerProviderProfile profile(UUID user, String lastVisit, int bookings, String spent, int noShows) {
        CustomerProviderProfile p = mock(CustomerProviderProfile.class);
        when(p.getUserId()).thenReturn(user);
        when(p.getLastVisitAt()).thenReturn(lastVisit == null ? null : Instant.parse(lastVisit));
        when(p.getTotalBookings()).thenReturn(bookings);
        when(p.getTotalSpent()).thenReturn(new BigDecimal(spent));
        when(p.getCurrency()).thenReturn("KZT");
        when(p.getNoShows()).thenReturn(noShows);
        return p;
    }

    @Test
    void servicesAreSortedByTitleAndKeepInactiveOnes() {
        ServiceOffering wax = offering("wax", 30, "3000", true);
        ServiceOffering brows = offering("Brows", 45, "5000", false);
        when(services.findByProviderId(PROVIDER)).thenReturn(List.of(wax, brows));

        var rows = service.backup(PROVIDER, null, null).services();

        assertThat(rows).extracting(r -> r.title()).containsExactly("Brows", "wax");
        assertThat(rows.get(0).active()).isFalse();
        assertThat(rows.get(0).durationMinutes()).isEqualTo(45);
        assertThat(rows.get(1).price()).isEqualByComparingTo("3000");
    }

    private static ServiceOffering offering(String title, int minutes, String price, boolean active) {
        ServiceOffering o = mock(ServiceOffering.class);
        when(o.getId()).thenReturn(UUID.randomUUID());
        when(o.getTitle()).thenReturn(title);
        when(o.getDurationMinutes()).thenReturn(minutes);
        when(o.getPrice()).thenReturn(new BigDecimal(price));
        when(o.getCurrency()).thenReturn("KZT");
        when(o.isActive()).thenReturn(active);
        return o;
    }

    @Test
    void theDefaultWindowIsThe30DaysBackAndTheNext180() {
        BackupResponse copy = service.backup(PROVIDER, null, null);

        assertThat(copy.from()).isEqualTo(NOW.minusSeconds(30L * 86400));
        assertThat(copy.to()).isEqualTo(NOW.plusSeconds(180L * 86400));
        assertThat(copy.generatedAt()).isEqualTo(NOW);
        assertThat(copy.providerId()).isEqualTo(PROVIDER);
    }

    @Test
    void anExplicitWindowIsKept() {
        Instant from = Instant.parse("2026-01-01T00:00:00Z");
        Instant to = Instant.parse("2026-02-01T00:00:00Z");

        BackupResponse copy = service.backup(PROVIDER, from, to);

        assertThat(copy.from()).isEqualTo(from);
        assertThat(copy.to()).isEqualTo(to);
    }

    @Test
    void aBackwardsOrTooWideWindowIsABadRequest() {
        Instant from = Instant.parse("2026-01-01T00:00:00Z");

        assertThatThrownBy(() -> service.backup(PROVIDER, from, from))
                .isInstanceOfSatisfying(ResponseStatusException.class,
                        e -> assertThat(e.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST));
        assertThatThrownBy(() -> service.backup(PROVIDER, from, from.plusSeconds(401L * 86400)))
                .isInstanceOf(ResponseStatusException.class);
        // 400 days exactly is allowed.
        assertThat(service.backup(PROVIDER, from, from.plusSeconds(400L * 86400)).bookings()).isEmpty();
    }
}
