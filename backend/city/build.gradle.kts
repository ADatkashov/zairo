description = "City management — multi-city support for a single country. Depended on by other modules."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.55")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("jakarta.validation:jakarta.validation-api")
    implementation(project(":platform-admin"))
    implementation(project(":users"))
    implementation(project(":auth"))
}
