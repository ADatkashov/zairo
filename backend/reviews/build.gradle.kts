description = "Reviews and ratings, tied to completed bookings only — no review without a verified visit."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Deliberate exception to the "reference other modules by id only" rule
    // used elsewhere (booking -> users/services): verifying "was this
    // booking actually completed" is a trust invariant, not just an
    // association, so reviews reads booking's status directly via its
    // repository rather than trusting client-supplied state. One-directional
    // (reviews -> booking), no cycle.
    implementation(project(":booking"))
}
