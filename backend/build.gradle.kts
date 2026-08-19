plugins {
    id("org.springframework.boot") version "4.1.0" apply false
    id("io.spring.dependency-management") version "1.1.7" apply false
    java
}

allprojects {
    group = "com.zairo.factory"
    version = "0.1.0"

    repositories {
        mavenCentral()
    }
}

// Every module — platform-api and every bounded-context module — shares the
// same Java toolchain and dependency management. Individual modules only
// declare what they add on top of this.
subprojects {
    apply(plugin = "java")
    apply(plugin = "io.spring.dependency-management")

    java {
        toolchain {
            languageVersion = JavaLanguageVersion.of(21)
        }
    }

    tasks.withType<Test> {
        useJUnitPlatform()
    }
}
