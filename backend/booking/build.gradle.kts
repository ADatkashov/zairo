description = "Booking Engine — Booking, Availability, TimeSlot. The heart of Factory's Commerce layer."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Trust invariant, not just an id reference: deleting an availability
    // slot has to prove the caller owns the provider it belongs to, which
    // needs providers' real data (Provider.ownerUserId) and auth's real
    // identity (CurrentUser) — same reasoning as services' equivalent
    // dependency.
    implementation(project(":providers"))
    implementation(project(":auth"))
    implementation(project(":money"))
}
