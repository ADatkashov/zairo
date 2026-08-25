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
    "vertical-auto",
    "storage",
    "country",
    "money",
    "payment-provider",
    "subscriptions",
)
