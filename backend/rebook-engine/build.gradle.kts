description = "Rebook Engine -- when a booking completes, works out this customer's usual visit interval " +
        "with the business and, once it's elapsed, nudges them to come back before they drift away. " +
        "Second RevenueStrategy plugged into the Decision Engine (see revenue-engine's package-info), " +
        "after Smart Fill."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")

    // A campaign's whole reason to exist: reacts to BookingCompletedEvent,
    // reads a customer's Booking/AvailabilitySlot history with a provider to
    // establish their usual visit interval, and listens for
    // BookingConfirmedEvent to close a campaign out the moment that customer
    // actually comes back (whether or not they ever saw the nudge).
    implementation(project(":booking"))

    // Provider.name/ServiceOffering.title for the nudge notification's copy
    // -- same "trust invariant, not just an association" reasoning
    // smart-fill/build.gradle.kts already documents for its own dependency.
    implementation(project(":providers"))
    implementation(project(":services"))

    // RebookCampaign snapshots the completed booking's price as a Money
    // value type, same embedding pattern as smart-fill.SmartFillCampaign.
    implementation(project(":money"))

    // Publishes RebookOfferReadyEvent for notifications to turn into a real
    // email -- this module never calls NotificationService directly, same
    // one-directional "publisher doesn't depend on the subscriber" pattern
    // as every other domain event in this codebase (ADR-0002).

    // Rebook is the Decision Engine's second RevenueStrategy (see
    // revenue-engine's package-info) -- RebookStrategy implements that
    // interface, and RebookCampaignService reports its outcome back through
    // RevenueAttributionService once a campaign resolves. One-directional:
    // revenue-engine has no knowledge of this module.
    implementation(project(":revenue-engine"))
}
