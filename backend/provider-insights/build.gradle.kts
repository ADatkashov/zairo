description = "Business-owner-facing read composition over existing operational data — customer " +
        "history and dashboard metrics for one provider. Owns no tables of its own; same " +
        "read-composition shape as the search module, scoped to a single business instead of " +
        "the whole marketplace."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.38")
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
}
