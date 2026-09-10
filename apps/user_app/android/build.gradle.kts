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
    project.evaluationDependsOn(":app")
}

// NOTE: apps/business_admin/android/build.gradle.kts carries a subprojects
// block working around an AGP-9/Kotlin-Gradle-Plugin gap in file_picker.
// This app no longer depends on file_picker (see pubspec.yaml — replaced by
// image_picker + image_cropper for the avatar/photo flows), and
// image_cropper hasn't shown the same symptom, so that workaround isn't
// needed here. If a future plugin here hits "cannot find symbol" for a
// class that should come from its own Kotlin sources, see that file's
// comment for the fix.

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
