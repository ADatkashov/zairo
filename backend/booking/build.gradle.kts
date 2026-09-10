description = "Booking Engine — Booking, Availability, TimeSlot. The heart of Factory's Commerce layer."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.38")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // Trust invariant, not just an id reference: deleting an availability
    // slot has to prove the caller owns the provider it belongs to, which
    // needs providers' real data (Provider.ownerUserId) and auth's real
    // identity (CurrentUser) — same reasoning as services' equivalent
    // dependency.
    implementation(project(":providers"))
    implementation(project(":auth"))
    implementation(project(":money"))

    // Creating a booking is gated by the owner's subscription plan's
    // monthly booking-count limit — see SubscriptionLimitService.
    implementation(project(":subscriptions"))

    // Deliberate exception to the "reference other modules by id only" rule
    // used elsewhere: a booking's price is a trust invariant, not just an
    // association — BookingService.createBooking reads the service's real
    // price/currency directly via its repository instead of trusting a
    // client-supplied totalPrice (same reasoning reviews already applies to
    // its own booking -> booking-status dependency). One-directional
    // (booking -> services), no cycle: services never depends on booking.
    implementation(project(":services"))
}
