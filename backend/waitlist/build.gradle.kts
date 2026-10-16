description = "Waitlist — a customer asks to be told when a time frees up at a business that is fully booked."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Listens for booking's "a slot is open again" event; reads provider names for the list; the caller must be the
    // user in the path (auth's CurrentUser). Same one-directional shape as favorites.
    implementation(project(":booking"))
    implementation(project(":providers"))
    implementation(project(":auth"))
}
