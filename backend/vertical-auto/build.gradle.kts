description = "Auto vertical: mechanics, vehicles, and the booking rule that an auto booking must name a mechanic who actually offers the requested service, for a vehicle the customer actually owns."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // Read-composition over Core to validate vertical data against real
    // provider/service records — same pattern as vertical-beauty.
    implementation(project(":providers"))
    implementation(project(":services"))

    // Deliberate exception to "reference other modules by id only", same
    // class of exception as vertical-beauty -> booking: an auto booking has
    // to go through booking's own BookingService.createBooking (not just
    // its repository) to reuse the atomic OPEN -> BOOKED slot claim.
    // One-directional (vertical-auto -> booking), no cycle.
    implementation(project(":booking"))

    // Ownership check on mechanic mutations, and self-service check on
    // vehicle mutations, both need auth's real identity (CurrentUser) —
    // same reasoning as vertical-beauty's own dependency.
    implementation(project(":auth"))

    // Creating a mechanic is gated by the owner's subscription plan's
    // staff-count limit — see SubscriptionLimitService.
    implementation(project(":subscriptions"))
}
