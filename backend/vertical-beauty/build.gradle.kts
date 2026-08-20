description = "Beauty vertical: masters, portfolios, and the booking rule that a beauty booking must name a master who actually offers the requested service."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Read-composition over Core to validate vertical data against real
    // provider/service records — same pattern as search/favorites reading
    // providers/services directly.
    implementation(project(":providers"))
    implementation(project(":services"))

    // Deliberate exception to "reference other modules by id only", same
    // class of exception as reviews -> booking: a beauty booking has to go
    // through booking's own BookingService.createBooking (not just its
    // repository) to reuse the atomic OPEN -> BOOKED slot claim. Re-deriving
    // that logic here would risk drifting out of sync with Core and
    // reintroducing the double-booking race @Version was built to prevent.
    // One-directional (vertical-beauty -> booking), no cycle.
    implementation(project(":booking"))

    // Ownership check on master mutations (create/portfolio/link/deactivate)
    // needs auth's real identity (CurrentUser) — same reasoning as the new
    // dependency added to services/booking for their own write endpoints.
    implementation(project(":auth"))
}
