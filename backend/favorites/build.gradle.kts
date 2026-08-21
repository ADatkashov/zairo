description = "Saved/favorited providers — a user's shortlist, shown as full provider cards."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Pure read-composition over other modules' data, same justification
    // as search -> providers/services/booking: this is a query/display
    // concern, not a business invariant. One-directional, no cycles.
    // favorites doesn't depend on search (a sibling Discovery-layer
    // module) — both read Layer 1 independently, per the Core/Marketplace
    // layering in the Factory Blueprint.
    implementation(project(":providers"))
    implementation(project(":services"))
    implementation(project(":booking"))

    // Only for ReviewSummaryService's batched rating aggregate — same
    // reasoning as search/build.gradle.kts.
    implementation(project(":reviews"))
}
