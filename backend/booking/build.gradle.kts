description = "Booking Engine — Booking, Availability, TimeSlot. The heart of Factory's Commerce layer."

dependencies {
    implementation("org.springframework.security:spring-security-core:7.1.1")
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
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

    // Booking captures a provider's deposit policy on itself at creation
    // time (Booking.depositType/depositValueType/depositAmount) — see
    // BookingService.createBooking. Depends on the dependency-free
    // deposit-policy module directly, not on payments itself, to avoid a
    // cycle: payments already depends on booking (to read the booking
    // being charged), so booking -> payments would loop back.
    implementation(project(":deposit-policy"))

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

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.assertj:assertj-core")
}
