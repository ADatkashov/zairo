description = "Smart Fill Engine -- when a booking is cancelled, finds, scores, and stages offers of the " +
        "freed slot to the customers most likely to want it, so a cancellation doesn't have to mean lost " +
        "revenue. First slice of what can grow into a general revenue-recovery engine (see package-info)."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.38")
    implementation("org.springframework.boot:spring-boot-starter")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // Ownership check for the one owner-facing read this module exposes
    // directly, and CurrentUser for the customer-facing offer endpoints.
    implementation(project(":auth"))

    // Provider.vertical/businessTypeId for category-interest scoring, and
    // ProviderOwnership isn't used here directly (provider-insights already
    // owns the owner-facing surface) but Provider itself is real read data,
    // not just an id, once a campaign needs the business's name for its
    // notification's copy.
    implementation(project(":providers"))

    // A campaign's whole reason to exist: reacts to BookingCancelledEvent,
    // reads Booking/AvailabilitySlot history to find and score candidates,
    // and listens for AvailabilitySlotBookedEvent to close a campaign the
    // instant its slot is claimed by anyone.
    implementation(project(":booking"))

    // ServiceOffering's price/duration for the recovered-revenue estimate
    // and the notification's copy -- same "trust invariant, not just an
    // association" reasoning booking/build.gradle.kts already documents
    // for its own dependency on services.
    implementation(project(":services"))

    // SmartFillCampaign snapshots the service's price as a Money value type
    // (see that field's own doc comment), same embedding pattern as
    // services.ServiceOffering/booking.Booking.
    implementation(project(":money"))

    // Candidate pool + scoring signals: who has booked here before
    // (users), who favorited this provider (favorites).
    implementation(project(":users"))
    implementation(project(":favorites"))

    // Best-effort employee display name for the notification's copy, via
    // the generic vertical-agnostic staff directory only -- AvailabilitySlot
    // .employeeId is opaque and may equally point at a vertical-beauty
    // Master/vertical-auto Mechanic/vertical-cleaning Cleaner row instead
    // (see AvailabilitySlot's own doc comment); this module stays
    // vertical-agnostic on purpose (same boundary staff's own package-info
    // draws) rather than depending on all three vertical modules just to
    // resolve a name, so a vertical-specific employee simply gets no name
    // in the notification, not a broken one.
    implementation(project(":staff"))

    // Publishes SmartFillOfferReadyEvent for notifications to turn into a
    // real email -- this module never calls NotificationService directly,
    // same one-directional "publisher doesn't depend on the subscriber"
    // pattern as every other domain event in this codebase (ADR-0002).
}
