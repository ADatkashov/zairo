description = "Search and deterministic ranking over Providers/Services — rating, distance, price, availability."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")

    // Pure read-composition over other modules' data (a search/query bounded
    // context reading other aggregates directly is a standard modular
    // monolith pattern, distinct from booking -> users/services which is
    // id-only association, and from reviews -> booking which verifies a
    // trust invariant). One-directional, no cycles.
    implementation(project(":providers"))
    implementation(project(":services"))
    implementation(project(":booking"))

    // Only for ReviewSummaryService's batched rating aggregate — see its
    // doc comment for why this is one query per search request, not a
    // per-provider join.
    implementation(project(":reviews"))

    // businessTypeId filtering + matching a free-text query against a
    // linked catalog entry's multilingual name, not just a provider's own
    // service titles — see SearchService.search.
    implementation(project(":catalog"))

    // Self-service check on BookAgainController.bookAgain needs auth's
    // real identity (CurrentUser) — same reasoning as every other
    // self-service-only endpoint in this codebase.
    implementation(project(":auth"))

    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.assertj:assertj-core")
}
