description = "Generic marketplace Provider (salon, workshop, dentist, ...). Vertical-agnostic."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Creating/editing a provider requires proving who you are and that
    // you're the one being named as owner — needs auth's real identity
    // (CurrentUser), same reasoning as the dependency added to
    // services/booking/vertical-beauty for their own write endpoints.
    implementation(project(":auth"))
}
