description = "Port to an external payment provider (charge/refund by idempotency-key id) — extracted out of payments once subscriptions needed the exact same port for recurring charges, without pulling in payments' own booking dependency (which would have created a module cycle: providers -> subscriptions -> payments -> booking -> providers). Depends on none of the other bounded-context modules."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter")

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}
