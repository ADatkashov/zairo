description = "Reviews and ratings, tied to completed bookings only — no review without a verified visit."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.38")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // Deliberate exception to the "reference other modules by id only" rule
    // used elsewhere (booking -> users/services): verifying "was this
    // booking actually completed" is a trust invariant, not just an
    // association, so reviews reads booking's status directly via its
    // repository rather than trusting client-supplied state. One-directional
    // (reviews -> booking), no cycle.
    implementation(project(":booking"))

    // Replying to a review needs "does this caller own the reviewed
    // booking's provider" (ProviderOwnership) and "who is this caller"
    // (CurrentUser) — same two dependencies booking itself already takes
    // for its own owner-only endpoints (markNoShow, etc.), same reasoning.
    implementation(project(":providers"))
    implementation(project(":auth"))
}
