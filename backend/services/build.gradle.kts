description = "Generic marketplace Service (what a Provider offers, with a price). Vertical-agnostic."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // Trust invariants, not just id references (same exception class as
    // reviews -> booking): editing/deactivating a service has to prove the
    // caller actually owns the provider it belongs to, which needs
    // providers' real data (Provider.ownerUserId) and auth's real identity
    // (CurrentUser), not something a client-supplied id could fake.
    implementation(project(":providers"))
    implementation(project(":auth"))
    implementation(project(":money"))

    // Validating a catalog-link target actually exists — see
    // ServiceOfferingController.linkCatalogService.
    implementation(project(":catalog"))

    implementation(project(":city"))
    implementation(project(":users"))
}
