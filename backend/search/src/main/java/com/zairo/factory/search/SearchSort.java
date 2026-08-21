package com.zairo.factory.search;

/**
 * RECOMMENDED is the existing default ranking (open availability first,
 * then distance, then cheapest price) — unchanged by adding explicit sort
 * options. RATING is deliberately not offered yet: it needs a
 * review -> booking -> availability_slot -> provider join with no direct
 * FK shortcut (see SearchService's doc comment), which is Phase 2 Item 6's
 * job to analyze before wiring in, not something to bolt on here first.
 */
public enum SearchSort {
    RECOMMENDED,
    PRICE_ASC,
    PRICE_DESC,
    DISTANCE
}
