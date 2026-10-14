description = "The people who actually serve customers — beauty masters, auto mechanics, cleaners and generic staff — seen as one kind of thing (a worker): their own cabinet, the owner-managed weekly schedule and time off, protection from being booked in two places at once, 'any master' assignment and what happens when someone can't make it. The four directories (vertical-beauty/auto/cleaning, staff) stay untouched; this module reads and writes their tables through one small mapping."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    implementation(project(":providers"))
    implementation(project(":services"))
    implementation(project(":auth"))
    implementation(project(":users"))

    // Acting on bookings goes through booking's own service (state rules, slot release, refund events) — the same
    // deliberate one-directional exception the vertical modules and staff already take.
    implementation(project(":booking"))

    // The cabinet shows each worker's rating and the reviews left on their appointments.
    implementation(project(":reviews"))

    // "Any master" books on the customer's behalf through each directory's own booking service. One-directional
    // (workforce -> verticals/staff); none of them depends on workforce (they only see booking's guard interface).
    implementation(project(":vertical-beauty"))
    implementation(project(":vertical-auto"))
    implementation(project(":vertical-cleaning"))
    implementation(project(":staff"))

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.assertj:assertj-core")
}
