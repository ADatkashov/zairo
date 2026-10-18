description = "Automation Center -- per-business configuration over the three revenue-recovery engines " +
        "(Smart Fill, Rebook, Reactivation): enable/disable each independently, override their global " +
        "audience-rule tuning, and set quiet hours/timezone/cooldown so a business isn't nudging its own " +
        "customers around the clock. Deliberately owns only the settings row, not the engines themselves -- " +
        "smart-fill/rebook-engine/reactivation-engine each depend on this module to read it (one-directional, " +
        "no cycle), the same way they'd depend on any other shared config source."

dependencies {
    implementation("org.springframework.security:spring-security-core:7.1.1")
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Ownership check + CurrentUser for the one owner-only settings endpoint
    // this module exposes directly -- same two dependencies every other
    // owner-only surface in this codebase takes (see loyalty/reviews).
    implementation(project(":providers"))
    implementation(project(":auth"))
}
