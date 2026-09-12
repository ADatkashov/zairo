description = "Customer Intelligence: turns raw booking history into per-customer behavioural profiles -- " +
        "visit cadence, spending, preferences, attendance, retention -- computed deterministically and " +
        "persisted so Revenue Engine strategies (Smart Fill, Rebook, and future ones) and business-admin " +
        "surfaces can read them cheaply instead of re-deriving them from Booking on every call. See this " +
        "module's own package-info.java."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.38")
    implementation("org.springframework.boot:spring-boot-starter")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // A profile's whole reason to exist: reacts to BookingConfirmedEvent/
    // BookingCompletedEvent/BookingCancelledEvent/BookingNoShowEvent and
    // reads Booking/AvailabilitySlot history to compute it -- same data
    // source as providerinsights.ProviderInsightsService and
    // smartfill.CandidateFinder, just persisted instead of computed fresh
    // on every read (this module's whole point is being cheap to read many
    // times over, e.g. once per Smart Fill candidate).
    implementation(project(":booking"))

    // Ownership check for the one business-admin read this module exposes
    // directly (a business only ever sees its own customers' intelligence),
    // and CurrentUser for the customer-facing self-service endpoint.
    implementation(project(":auth"))
    implementation(project(":providers"))

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}
