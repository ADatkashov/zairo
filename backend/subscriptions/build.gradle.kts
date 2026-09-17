description = "Subscription/billing — tariff plans, usage limits, and the recurring MockPaymentProvider charge cycle."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    implementation(project(":money"))

    // Charging a subscription reuses the same PaymentProvider port
    // (charge/refund by idempotency-key id) that payments also uses for
    // booking charges — one interface, two callers. Depends on the
    // dependency-free payment-provider module directly, not on payments
    // itself, to avoid a cycle (payments -> booking -> providers ->
    // subscriptions would loop back to subscriptions -> payments).
    implementation(project(":payment-provider"))

    // Subscription endpoints are owner-only (CurrentUser.requireUserId) —
    // same reasoning as providers' own dependency on auth.
    implementation(project(":auth"))

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}
