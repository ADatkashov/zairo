description = "ZAIRO Intelligence/Decision Engine foundation -- a use-case-agnostic way to compare candidate " +
        "revenue-recovery actions (Smart Fill today; rebooking, reactivation, gap-fill, targeted promotion, " +
        "no-show prevention, VIP retention tomorrow) by expected value, execute the best one, and record its " +
        "outcome. Owns no domain logic of its own -- see this module's package-info."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.38")
    implementation("org.springframework.boot:spring-boot-starter")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")

    // Listens for BookingCancelledEvent (today's one real decision point) --
    // same one-directional "listen for the event" reasoning notifications'
    // build.gradle.kts already documents for its own booking dependency.
    // Does NOT depend on smart-fill or any other strategy module -- those
    // depend on this module instead (RevenueStrategy is the seam), never
    // the other way, so a new strategy module never risks a dependency
    // cycle back into whatever it acts on.
    implementation(project(":booking"))
}
