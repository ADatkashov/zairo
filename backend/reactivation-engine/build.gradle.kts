description = "Lost Customer Recovery -- a daily sweep for customers who have gone quiet well past their usual " +
        "visit interval (or, absent an established pattern, a flat long-inactivity floor), and a win-back " +
        "nudge for each one found. Third RevenueStrategy plugged into the Decision Engine (see " +
        "revenue-engine's package-info), after Smart Fill and Rebook."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")

    // The sweep's whole reason to exist: scans Booking/AvailabilitySlot for
    // every customer+provider pair's most recent completed visit, and
    // listens for BookingConfirmedEvent to close a campaign out the moment
    // that exact customer books with that provider again.
    implementation(project(":booking"))

    // Provider.name/ServiceOffering.title for the win-back notification's
    // copy -- same "trust invariant, not just an association" reasoning
    // rebook-engine/build.gradle.kts already documents for its own
    // dependency.
    implementation(project(":providers"))
    implementation(project(":services"))

    // ReactivationCampaign snapshots the customer's last-visit price as a
    // Money value type, same embedding pattern as rebookengine.RebookCampaign.
    implementation(project(":money"))

    // Publishes ReactivationOfferReadyEvent for notifications to turn into a
    // real email -- this module never calls NotificationService directly,
    // same one-directional "publisher doesn't depend on the subscriber"
    // pattern as every other domain event in this codebase (ADR-0002).

    // Lost Customer Recovery is the Decision Engine's third RevenueStrategy
    // (see revenue-engine's package-info) -- ReactivationStrategy implements
    // that interface, and its discovery job calls DecisionEngine directly
    // for each inactive customer it finds (DecisionTrigger.CUSTOMER_INACTIVE
    // has no single triggering event -- see that constant's own doc
    // comment). One-directional: revenue-engine has no knowledge of this
    // module, and this module has no knowledge of rebook-engine/smart-fill
    // (sibling strategies never depend on each other).
    implementation(project(":revenue-engine"))
}
