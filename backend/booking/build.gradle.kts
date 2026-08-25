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
}
