pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}

rootProject.name = "app-factory-backend"

include(
    "platform-api",
    "auth",
    "users",
    "providers",
    "services",
    "booking",
    "payments",
    "reviews",
    "notifications",
    "search",
    "favorites",
    "vertical-beauty",
    "storage",
    "country",
    "money",
)
