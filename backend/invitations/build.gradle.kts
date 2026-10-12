description = "Staff invitations: an owner invites a not-yet-registered person by phone; when that number is verified (sign-up or linking), they are attached to the business as a master / mechanic / cleaner / staff member."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    implementation(project(":providers"))
    implementation(project(":users"))
    // CurrentUser, the phone normalizer and PhoneVerifiedEvent.
    implementation(project(":auth"))

    // Attaching the invited person goes through each directory's own create-from-user
    // method, so the plan's staff limit and vertical checks still apply.
    implementation(project(":vertical-beauty"))
    implementation(project(":vertical-auto"))
    implementation(project(":vertical-cleaning"))
    implementation(project(":staff"))

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.assertj:assertj-core")
}
