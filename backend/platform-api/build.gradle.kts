plugins {
    id("org.springframework.boot")
    application
}

description = "Assembly module — wires every bounded-context module into one deployable Spring Boot app (modular monolith)."

// spring-boot-testcontainers pulls org.testcontainers:testcontainers itself
// at the version Spring Boot 4.1.0 pins (2.0.5) via its own POM, but that
// doesn't extend to sibling testcontainers artifacts we depend on directly
// — io.spring.dependency-management doesn't resolve spring-boot-dependencies'
// nested import of testcontainers-bom transitively, so pin explicitly to the
// same version instead. Note: Testcontainers 2.x renamed the module
// artifacts with a "testcontainers-" prefix (testcontainers-postgresql,
// testcontainers-junit-jupiter), unlike the old 1.x "postgresql"/
// "junit-jupiter" coordinates.
val testcontainersVersion = "2.0.5"

dependencies {
    implementation(project(":auth"))
    implementation(project(":users"))
    implementation(project(":providers"))
    implementation(project(":services"))
    implementation(project(":booking"))
    implementation(project(":payments"))
    implementation(project(":reviews"))
    implementation(project(":notifications"))
    implementation(project(":search"))
    implementation(project(":favorites"))
    implementation(project(":vertical-beauty"))

    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    // Spring Boot 4.1 split Flyway's autoconfiguration into its own starter
    // (spring-boot-flyway) — flyway-core alone doesn't wire the
    // FlywayMigrationInitializer, so migrations silently never ran.
    implementation("org.springframework.boot:spring-boot-starter-flyway")
    implementation("org.flywaydb:flyway-database-postgresql")
    runtimeOnly("org.postgresql:postgresql")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    // Spring Boot 4.1 moved TestRestTemplate out of spring-boot-test into its
    // own module (org.springframework.boot.resttestclient package).
    testImplementation("org.springframework.boot:spring-boot-resttestclient")
    // resttestclient's autoconfiguration reflects on RestTemplateBuilder,
    // which now lives in its own restclient module too.
    testImplementation("org.springframework.boot:spring-boot-restclient")
    testImplementation("org.springframework.boot:spring-boot-testcontainers")
    testImplementation("org.testcontainers:testcontainers-junit-jupiter:$testcontainersVersion")
    testImplementation("org.testcontainers:testcontainers-postgresql:$testcontainersVersion")
}

application {
    mainClass.set("com.zairo.factory.platform.PlatformApiApplication")
}
