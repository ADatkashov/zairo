description = "Platform-wide read composition for the Control Center dashboard — Users/Businesses/" +
        "Subscriptions/Bookings/Payments/Revenue, all live-query, same 'compute fresh, own no " +
        "tables' shape as provider-insights, scoped to the whole marketplace instead of one " +
        "business. See docs/PRODUCT_PRODUCTION_ROADMAP.md section 9 for the exact scope and what " +
        "was deliberately left out (funnel/DAU-WAU-MAU/system health all need a new analytics_event " +
        "model that doesn't exist yet)."

dependencies {
    implementation("org.springframework.security:spring-security-core:7.1.1")
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Gated by PLATFORM_ADMIN/PLATFORM_SUPPORT — reuses platform-admin's
    // caller resolution wholesale, same directed dependency shape as
    // catalog -> platform-admin.
    implementation(project(":platform-admin"))

    implementation(project(":users"))
    implementation(project(":providers"))
    implementation(project(":subscriptions"))
    implementation(project(":booking"))
    implementation(project(":payments"))
    implementation(project(":reviews"))
}
