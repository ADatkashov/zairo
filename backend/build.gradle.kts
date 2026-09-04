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

    // Without -parameters, Spring MVC can't resolve @PathVariable names via
    // reflection (only positional info), so every @PathVariable would need
    // an explicit name argument. Compile with it everywhere instead.
    tasks.withType<JavaCompile> {
        options.compilerArgs.add("-parameters")
    }

    // Bounded-context modules (providers, services, ...) declare Spring Boot
    // starter dependencies without version numbers but don't apply the
    // org.springframework.boot plugin themselves (only platform-api does,
    // since it's the one runnable app) — so the BOM has to be imported
    // explicitly here for every subproject to get managed versions.
    configure<io.spring.gradle.dependencymanagement.dsl.DependencyManagementExtension> {
        imports {
            mavenBom("org.springframework.boot:spring-boot-dependencies:4.1.0")
        }
    }

    tasks.withType<Test> {
        useJUnitPlatform()
        testLogging {
            exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
            showCauses = true
            showStackTraces = true
        }
    }
}
