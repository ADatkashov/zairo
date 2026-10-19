description = "Business-owner-facing read composition over existing operational data — customer " +
        "history and dashboard metrics for one provider. Owns no tables of its own; same " +
        "read-composition shape as the search module, scoped to a single business instead of " +
        "the whole marketplace."

dependencies {
    implementation("org.springframework.security:spring-security-core:7.1.1")
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Ownership check (only the provider's own owner can see its customer
    // history/dashboard) needs auth's real identity and providers' real
    // ownership data.
    implementation(project(":providers"))
    implementation(project(":auth"))

    // Reading bookings/payments for this provider, and a booked service's
    // title for "favorite service".
    implementation(project(":booking"))
    implementation(project(":payments"))
    implementation(project(":services"))

    // Customer display name/email for the ids booking already carries.
    implementation(project(":users"))

    // Smart Fill performance (recovered slots/revenue, campaign/offer
    // conversion) is exposed under this module's existing owner-facing
    // dashboard rather than a second admin surface -- read-composition
    // only, same reasoning as the dependencies above.
    implementation(project(":smart-fill"))

    // "Revenue Recovered by ZAIRO" -- the Decision Engine's own outcome
    // ledger, spanning every RevenueStrategy (Smart Fill today, more
    // later), same read-composition reasoning as the dependency above.
    implementation(project(":revenue-engine"))

    // Business Analytics' customer section and Action Center read
    // Customer Intelligence's already-computed per-business retention
    // classification (due-for-rebooking/at-risk/etc.) rather than
    // recomputing any of it here -- same read-composition reasoning as
    // the dependencies above.
    implementation(project(":customer-intelligence"))

    // The weekly report quotes the week's average rating.
    implementation(project(":reviews"))
}
