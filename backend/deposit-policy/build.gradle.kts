description = "Deposit policy — DepositType/DepositValueType/DepositCalculator and each provider's " +
        "PaymentSettings (deposit policy config). Extracted out of payments: booking captures a " +
        "provider's deposit settings on the Booking entity at creation time (see Booking's " +
        "depositType/depositValueType fields), but payments already depends on booking (to read the " +
        "booking being paid for) — booking depending on payments back would be a module cycle. Same " +
        "fix as payment-provider's own extraction (see payment-provider/build.gradle.kts): pull the " +
        "shared piece into its own dependency-free module instead. Depends on none of the other " +
        "bounded-context modules."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}
