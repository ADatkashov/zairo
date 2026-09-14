description = "Generic staff directory and staff-scoped booking, usable by ANY provider regardless of vertical — unlike vertical-beauty/vertical-auto/vertical-cleaning, this module reads no Provider.vertical string at all. New categories (medicine, home repair, tutoring, ...) get staff selection at booking time without a new Java module or a release; those three existing modules are untouched and keep working exactly as they do today."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // Read-composition over Core to validate staff data against real
    // provider/service records — same pattern as vertical-beauty/auto/cleaning.
    implementation(project(":providers"))
    implementation(project(":services"))

    // Deliberate exception to "reference other modules by id only", same
    // class of exception the vertical modules already take: a staff
    // booking has to go through booking's own BookingService.createBooking
    // (not just its repository) to reuse the atomic OPEN -> BOOKED slot
    // claim. One-directional (staff -> booking), no cycle.
    implementation(project(":booking"))

    // Ownership check on staff mutations (create/link/deactivate) needs
    // auth's real identity (CurrentUser).
    implementation(project(":auth"))

    // Creating a staff member is gated by the owner's subscription plan's
    // staff-count limit — see SubscriptionLimitService.
    implementation(project(":subscriptions"))
}
