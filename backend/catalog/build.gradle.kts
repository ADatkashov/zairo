description = "Platform master catalog — Category / BusinessType / CatalogService, the " +
        "admin-curated taxonomy businesses select from. Not a business's own service list " +
        "(see services.ServiceOffering for that)."

dependencies {
    implementation("org.springframework.security:spring-security-core:7.1.1")
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // Admin mutations reuse platform-admin's caller/audit-log machinery
    // wholesale instead of a second admin auth system — same directed
    // dependency shape as auth -> users.
    implementation(project(":platform-admin"))

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.assertj:assertj-core")
}
