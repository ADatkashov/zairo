description = "Payments — deposits, refunds, commission. Payment provider webhook is the source of truth, never the client."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.38")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Needs to read the booking being paid for (amount, existence) — same
    // one-directional dependency pattern as reviews -> booking.
    implementation(project(":booking"))
    implementation(project(":money"))

    // Charging/reading a booking's payment is restricted to that booking's
    // own customer or its provider's own owner — same "who is this caller"
    // (CurrentUser) and "does this caller own this provider" (ProviderOwnership)
    // dependencies booking itself already takes for its own owner-only
    // endpoints, reused here rather than a new auth mechanism.
    implementation(project(":auth"))
    implementation(project(":providers"))

    // The PaymentProvider port itself now lives in its own dependency-free
    // module — see payment-provider/build.gradle.kts for why (subscriptions
    // needed the same port without a Gradle cycle).
    implementation(project(":payment-provider"))

    // The failed-refund admin visibility endpoint (PaymentAdminController)
    // reuses platform-admin's caller resolution wholesale instead of a
    // second admin auth system — same directed dependency shape as
    // catalog -> platform-admin.
    implementation(project(":platform-admin"))
}
