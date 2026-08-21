description = "Money value type — amount + validated ISO 4217 currency, one shared representation instead of independent amount/currency column pairs. Depended on by other modules; depends on none of them."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}
