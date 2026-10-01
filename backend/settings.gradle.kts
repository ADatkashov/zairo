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
    "city",
    "money",
    "payment-provider",
    "deposit-policy",
    "subscriptions",
    "platform-admin",
    "catalog",
    "provider-insights",
    "platform-insights",
    "messaging",
    "revenue-engine",
    "automation",
    "smart-fill",
    "rebook-engine",
    "customer-intelligence",
    "reactivation-engine",
    "campaign-center",
    "loyalty",
)
