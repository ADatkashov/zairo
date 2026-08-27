description = "Generic marketplace Provider (salon, workshop, dentist, ...). Vertical-agnostic."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.38")
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
}
