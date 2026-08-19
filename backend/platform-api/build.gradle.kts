plugins {
    id("org.springframework.boot")
    application
}

description = "Assembly module — wires every bounded-context module into one deployable Spring Boot app (modular monolith)."

dependencies {
    implementation(project(":auth"))
    implementation(project(":users"))
    implementation(project(":providers"))
    implementation(project(":services"))
    implementation(project(":booking"))
    implementation(project(":payments"))
    implementation(project(":reviews"))
    implementation(project(":notifications"))
    implementation(project(":search"))

    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
}

application {
    mainClass.set("com.zairo.factory.platform.PlatformApiApplication")
}
