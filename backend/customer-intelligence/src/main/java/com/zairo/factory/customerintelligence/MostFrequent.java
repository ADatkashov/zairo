package com.zairo.factory.customerintelligence;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;

/** "Favourite provider/service/employee" -- the id that appears most often among a list of completed visits. */
final class MostFrequent {

    private MostFrequent() {
    }

    static Optional<UUID> of(List<VisitRecord> completedVisits, Function<VisitRecord, UUID> key) {
        // LinkedHashMap: first-seen order is the tie-break when two ids are equally frequent, so the
        // result is deterministic rather than depending on hash iteration order.
        Map<UUID, Long> counts = new LinkedHashMap<>();
        for (VisitRecord visit : completedVisits) {
            UUID id = key.apply(visit);
            if (id != null) {
                counts.merge(id, 1L, Long::sum);
            }
        }
        return counts.entrySet().stream().max(Map.Entry.comparingByValue()).map(Map.Entry::getKey);
    }
}
