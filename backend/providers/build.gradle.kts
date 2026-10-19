description = "Generic marketplace Provider (salon, workshop, dentist, ...). Vertical-agnostic."

dependencies {
    implementation("org.springframework.security:spring-security-core:7.1.1")
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // Creating/editing a provider requires proving who you are and that
    // you're the one being named as owner — needs auth's real identity
    // (CurrentUser), same reasoning as the dependency added to
    // services/booking/vertical-beauty for their own write endpoints.
    implementation(project(":auth"))

    // Creating a provider is gated by the owner's subscription plan's
    // provider-count limit — see SubscriptionLimitService.
    implementation(project(":subscriptions"))

    // Resolving a new provider's businessTypeId from its vertical string at
    // creation time — see ProviderController.create.
    implementation(project(":catalog"))

    // Business moderation (approve/suspend/reinstate) is also reachable from
    // the Control Center now — reuses platform-admin's caller/audit-log
    // machinery wholesale instead of a second admin auth system, same
    // directed dependency shape as catalog -> platform-admin.
    implementation(project(":platform-admin"))

    // City management for multi-city support — providers are linked to cities
    implementation(project(":city"))
}
