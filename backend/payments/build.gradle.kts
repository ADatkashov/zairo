description = "Payments — deposits, refunds, commission. Payment provider webhook is the source of truth, never the client."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.38")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Needs to read the booking being paid for (amount, existence) — same
    // one-directional dependency pattern as reviews -> booking.
    implementation(project(":booking"))
    implementation(project(":money"))
}
