description = "Push and in-app notifications, triggered by domain events (e.g. BookingConfirmed) via in-process events."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Read-composition only (resolve a booking's customer/provider-owner
    // email to notify) — same "query, not invariant" reasoning as
    // search/favorites' direct dependencies on providers/services/booking,
    // not the "owns a trust invariant" reasoning behind e.g. reviews ->
    // booking. Notifications never writes to either module's tables.
    implementation(project(":users"))
    implementation(project(":providers"))
    implementation(project(":booking"))

    // PasswordResetRequestedEvent's type, and CurrentUser for
    // NotificationsController's ownership check (caller must be the
    // userId in the path) — same reasoning as favorites/build.gradle.kts.
    implementation(project(":auth"))

    // Only for SubscriptionPaymentFailedEvent/SubscriptionPastDueEvent's
    // types — same one-directional "listen for the event" reasoning as the
    // booking/auth dependencies above.
    implementation(project(":subscriptions"))

    // Only for PaymentRefundedEvent's type — same one-directional "listen
    // for the event" reasoning as the dependencies above.
    implementation(project(":payments"))

    // Only for SmartFillOfferReadyEvent's type — same one-directional
    // "listen for the event" reasoning as the dependencies above. The
    // event carries its own denormalized provider/service/employee display
    // strings, so this dependency is for the type alone, not to read
    // smart-fill's data.
    implementation(project(":smart-fill"))

    // Only for RebookOfferReadyEvent's type — same one-directional "listen
    // for the event" reasoning as the dependency above.
    implementation(project(":rebook-engine"))

    // Only for ReactivationOfferReadyEvent's type — same one-directional
    // "listen for the event" reasoning as the dependency above.
    implementation(project(":reactivation-engine"))

    // BirthdayBonusAwardedEvent -> in-app/email greeting; one-directional like the engines above.
    implementation(project(":loyalty"))
}
