package com.zairo.factory.customerintelligence;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.zairo.factory.booking.BookingStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class MostFrequentTest {

    @Test
    void picksTheServiceBookedMostOften() {
        UUID favouriteService = UUID.randomUUID();
        UUID otherService = UUID.randomUUID();
        List<VisitRecord> visits = List.of(visit(favouriteService), visit(favouriteService), visit(otherService));

        assertEquals(favouriteService, MostFrequent.of(visits, VisitRecord::serviceId).orElseThrow());
    }

    @Test
    void tiesResolveToWhicheverAppearedFirst() {
        UUID first = UUID.randomUUID();
        UUID second = UUID.randomUUID();
        List<VisitRecord> visits = List.of(visit(first), visit(second));

        assertEquals(first, MostFrequent.of(visits, VisitRecord::serviceId).orElseThrow());
    }

    @Test
    void emptyHistoryHasNoFavourite() {
        assertTrue(MostFrequent.of(List.of(), VisitRecord::serviceId).isEmpty());
    }

    private static VisitRecord visit(UUID serviceId) {
        Instant now = Instant.now();
        return new VisitRecord(UUID.randomUUID(), UUID.randomUUID(), serviceId, null, BookingStatus.COMPLETED, now,
                now, new BigDecimal("10.00"), "USD");
    }
}
