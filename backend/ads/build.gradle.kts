description = "Home-screen promo banners with an optional video link — shown in the customer app's " +
        "Home carousel. Step 1 (platform-curated): the platform creates and moderates banners; " +
        "business-bought placements build on the same table."

dependencies {
    implementation("org.springframework.security:spring-security-core:7.1.1")
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // Admin mutations reuse platform-admin's caller/audit-log machinery.
    implementation(project(":platform-admin"))

    // A banner's city must be a real one (checked in AdService instead of surfacing a foreign-key 500).
    implementation(project(":city"))

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.assertj:assertj-core")
    testImplementation("org.mockito:mockito-core")
}
