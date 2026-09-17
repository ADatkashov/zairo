description = "Loyalty & Rewards: a business-scoped points ledger and reward catalog -- customers earn " +
        "points with one specific business (never pooled across businesses, see this module's own " +
        "package-info) by completing bookings, and redeem them for that same business's own rewards. " +
        "Owns its own immutable transaction ledger (the source of truth) plus a cached account balance " +
        "and FIFO earn-lot bookkeeping for cheap, auditable point expiration."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // A booking reaching COMPLETED is the whole reason points get earned
    // (see LoyaltyEarningListener) -- same BookingCompletedEvent/
    // BookingRepository dependency shape as customer-intelligence.
    implementation(project(":booking"))

    // Ownership check for every business-admin endpoint, and CurrentUser
    // for the customer-facing self-service endpoints.
    implementation(project(":auth"))
    implementation(project(":providers"))

    // Displaying a customer's name/email on the business-admin loyalty
    // customer list -- read-only, same as provider-insights' own use of
    // this module for the same purpose.
    implementation(project(":users"))

    // The review-bonus earning rule listens for ReviewCreatedEvent.
    implementation(project(":reviews"))

    // A COMPLETED booking's payment refunded after the fact must claw back
    // its earned points (Phase 0 stabilization) -- listens for
    // PaymentRefundedEvent. One-directional: payments has no idea this
    // module exists.
    implementation(project(":payments"))

    // Read-only composition for the one enriched business-admin view that
    // merges a customer's platform retention signal with their loyalty
    // standing -- same read-composition reasoning as provider-insights/
    // campaign-center, never the other way around (customer-intelligence
    // has no idea this module exists).
    implementation(project(":customer-intelligence"))

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.assertj:assertj-core")
}
