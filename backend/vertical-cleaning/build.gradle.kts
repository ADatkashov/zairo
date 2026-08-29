description = "Cleaning vertical: cleaners, and the booking rule that a cleaning booking must name a cleaner who actually offers the requested service."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.38")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // Read-composition over Core to validate vertical data against real
    // provider/service records — same pattern as vertical-beauty/vertical-auto.
    implementation(project(":providers"))
    implementation(project(":services"))

    // Deliberate exception to "reference other modules by id only", same
    // class of exception vertical-beauty/vertical-auto already take: a
    // cleaning booking has to go through booking's own
    // BookingService.createBooking (not just its repository) to reuse the
    // atomic OPEN -> BOOKED slot claim. One-directional
    // (vertical-cleaning -> booking), no cycle.
    implementation(project(":booking"))

    // Ownership check on cleaner mutations (create/link/deactivate) needs
    // auth's real identity (CurrentUser).
    implementation(project(":auth"))

    // Creating a cleaner is gated by the owner's subscription plan's
    // staff-count limit — see SubscriptionLimitService.
    implementation(project(":subscriptions"))
}
