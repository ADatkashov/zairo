allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// file_picker (pinned to 12.0.0-beta.1 — see apps/business_admin/pubspec.yaml
// for why) only self-applies its own Kotlin Gradle Plugin when AGP < 9 (see
// its android/build.gradle: `if (!isAgp9OrAbove) apply plugin:
// 'org.jetbrains.kotlin.android'`). On this project's AGP 9.1.0, it expects
// something else to have already applied Kotlin support to ITS OWN
// subproject specifically — applying the plugin at the app module level
// (tried first) does nothing for a separate included subproject like
// :file_picker. Without this, FilePickerPlugin.kt never gets a
// :file_picker:compileDebugKotlin task at all, and the generated Java
// plugin registrant fails with "cannot find symbol: class FilePickerPlugin".
// Mirrors apps/user_app/android/build.gradle.kts's identical fix (it needs
// this too now that it also depends on file_picker).
subprojects {
    if (project.name == "file_picker") {
        project.pluginManager.apply("org.jetbrains.kotlin.android")
        // Kotlin defaults to JVM target 21; app/build.gradle.kts compiles
        // Java at 17 (compileOptions sourceCompatibility/targetCompatibility),
        // and Gradle rejects a mismatch between the two ("Inconsistent JVM
        // Target Compatibility Between Java and Kotlin Tasks").
        project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
