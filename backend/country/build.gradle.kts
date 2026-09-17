description = "Country configuration — the platform's regionalization boundary. Depended on by other modules; depends on none of them."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // CountryResolutionFilter/CountryContext are package-private on purpose
    // (encapsulation — other modules only ever call CountryContext's public
    // API), so their own unit tests have to live in this module rather than
    // platform-api's shared test sourceset like every *ApiTests class does.
    // spring-test alone (not the full spring-boot-starter-test) is enough
    // for MockHttpServletRequest/MockFilterChain — no Spring context needed.
    testImplementation("org.junit.jupiter:junit-jupiter")
    testImplementation("org.springframework:spring-test")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}
