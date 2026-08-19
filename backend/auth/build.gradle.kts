description = "Identity & access — authentication, tokens, sessions."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // BCrypt password hashing only — deliberately not spring-boot-starter-security,
    // which would auto-register a filter chain securing every endpoint by
    // default and force reconfiguring every controller/test written so far.
    // A hand-rolled JwtAuthFilter (see JwtAuthFilter.java) is a much smaller
    // change on top of the existing modules, matching the blueprint's
    // "custom JWT access/refresh in auth module" call (Factory Blueprint
    // §12) without adopting the full framework.
    // Pinned explicitly: spring-boot-dependencies only re-exports Spring
    // Security's BOM as a nested import, which io.spring.dependency-management
    // doesn't resolve transitively (same issue hit with testcontainers in
    // Phase 2 step 1 — see SESSION_NOTES.md).
    implementation("org.springframework.security:spring-security-crypto:7.1.0")

    implementation("io.jsonwebtoken:jjwt-api:0.13.0")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:0.13.0")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.13.0")

    // Registration creates the User row as part of the same transaction —
    // deliberate one-directional Gradle dependency on users, same
    // justification as reviews -> booking: this isn't just an id
    // association, auth owns the "does this account exist" invariant.
    implementation(project(":users"))
}
