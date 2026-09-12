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
    "vertical-cleaning",
    "staff",
    "storage",
    "country",
    "money",
    "payment-provider",
    "subscriptions",
    "platform-admin",
    "catalog",
    "provider-insights",
    "platform-insights",
    "messaging",
    "revenue-engine",
    "smart-fill",
    "rebook-engine",
    "reactivation-engine",
)
