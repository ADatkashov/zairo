description = "Platform staff identity, authorization, and audit log — completely separate from " +
        "the auth/users bounded context customers and business owners log into."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // BCrypt only, same reasoning as auth/build.gradle.kts: a hand-rolled
    // PlatformAuthFilter is a much smaller addition than adopting
    // spring-boot-starter-security, which would auto-secure every endpoint
    // in the whole platform-api deploy unit, not just this module's.
    implementation("org.springframework.security:spring-security-crypto:7.1.1")

    implementation("io.jsonwebtoken:jjwt-api:0.13.0")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:0.13.0")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.13.0")

    // Deliberately no implementation(project(":auth")) and no
    // implementation(project(":users")) — this module must not be able to
    // read a customer/business User row or reuse their JwtService even by
    // accident. Separation is enforced at the Gradle dependency graph, not
    // just by convention.

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}
