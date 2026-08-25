description = "Push and in-app notifications, triggered by domain events (e.g. BookingConfirmed) via in-process events."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")

    // Read-composition only (resolve a booking's customer/provider-owner
    // email to notify) — same "query, not invariant" reasoning as
    // search/favorites' direct dependencies on providers/services/booking,
    // not the "owns a trust invariant" reasoning behind e.g. reviews ->
    // booking. Notifications never writes to either module's tables.
    implementation(project(":users"))
    implementation(project(":providers"))
    implementation(project(":booking"))

    // Only for PasswordResetRequestedEvent's type — see auth/build.gradle.kts
    // for why auth doesn't depend back on notifications instead.
    implementation(project(":auth"))

    // Only for SubscriptionPaymentFailedEvent/SubscriptionPastDueEvent's
    // types — same one-directional "listen for the event" reasoning as the
    // booking/auth dependencies above.
    implementation(project(":subscriptions"))
}
