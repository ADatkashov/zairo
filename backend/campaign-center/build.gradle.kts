description = "Campaign Center + Smart Actions -- an owner-facing read-composition and safe-lifecycle-action " +
        "layer over the three existing campaign engines (Smart Fill, Rebook, Reactivation). Owns no tables of " +
        "its own; same read-composition shape as provider-insights, cutting across three sibling modules " +
        "instead of one."

dependencies {
    implementation("org.springframework.security:spring-security-core:7.1.1")
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Ownership check (only the provider's own owner can see/act on its
    // campaigns) needs auth's real identity and providers' real ownership
    // data, plus provider/service/staff display names for campaign cards.
    implementation(project(":providers"))
    implementation(project(":auth"))
    implementation(project(":services"))
    implementation(project(":staff"))
    implementation(project(":booking"))

    // The three campaign engines this module composes over -- their
    // lifecycle stays owned by each engine's own service (see this
    // module's package-info); campaign-center only reads their
    // repositories and calls their already-published pause/resume/cancel/
    // retry commands.
    implementation(project(":smart-fill"))
    implementation(project(":rebook-engine"))
    implementation(project(":reactivation-engine"))

    // The Decision Engine's own outcome ledger -- recovered revenue per
    // campaign is read from RevenueOutcome, never recomputed or guessed.
    implementation(project(":revenue-engine"))

    // Smart Actions' at-risk-customer/due-for-rebooking signals reuse
    // Customer Intelligence's already-computed per-business profiles,
    // same read-composition reasoning as provider-insights.
    implementation(project(":customer-intelligence"))
}
