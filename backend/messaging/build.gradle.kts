description = "Basic 1:1 text chat between a customer and a business — no attachments, no group " +
        "threads, no read receipts (all deliberately out of scope, see " +
        "docs/PRODUCT_PRODUCTION_ROADMAP.md section 14). Poll-based (plain REST GET), not real-time " +
        "(no WebSocket) — the simplest thing that actually closes the gap. A message may optionally " +
        "carry the booking it's about (sent from that booking's detail screen)."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")

    // Trust invariant, not just an id reference: replying as "the business"
    // needs providers' real ownership data and auth's real identity — same
    // reasoning as booking/services' equivalent dependencies.
    implementation(project(":providers"))
    implementation(project(":auth"))

    // Booking context (sendAsCustomerForBooking): verifying "does the caller
    // own this booking" and resolving its provider (booking -> availability
    // slot -> provider) are trust invariants, not just id references — same
    // reasoning and same dependency shape as reviews -> booking.
    implementation(project(":booking"))

    // Customer display name for each conversation in an inbox — there's no
    // client-usable "get user by id" (users.UserController's is admin-only),
    // so the name has to be resolved and embedded here, same reasoning and
    // same dependency shape as provider-insights -> users.
    implementation(project(":users"))
}
