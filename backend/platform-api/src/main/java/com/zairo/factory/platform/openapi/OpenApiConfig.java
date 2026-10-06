package com.zairo.factory.platform.openapi;

import com.zairo.factory.platform.error.ApiError;
import io.swagger.v3.core.converter.AnnotatedType;
import io.swagger.v3.core.converter.ModelConverters;
import io.swagger.v3.core.converter.ResolvedSchema;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.examples.Example;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.media.Content;
import io.swagger.v3.oas.models.media.MediaType;
import io.swagger.v3.oas.models.media.Schema;
import io.swagger.v3.oas.models.responses.ApiResponse;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import io.swagger.v3.oas.models.tags.Tag;
import java.util.List;
import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * The one place Swagger's top-level shape (title/description/version,
 * environment picker, JWT "Authorize" button, tag list/order) is defined.
 * Per-endpoint documentation ({@code @Operation}/{@code @ApiResponse}) lives
 * on each controller method instead — this only covers what's genuinely
 * global.
 *
 * <p>Tag descriptions are set here (by name) rather than repeating a
 * {@code @Tag} annotation with a description on every controller — a tag
 * spans several controllers in a few cases (Beauty), and this is the one
 * place order matters for how Swagger UI groups the sidebar.
 *
 * <p><b>Language switching</b> — {@link #russianApi()}/{@link #kazakhApi()}
 * below are additional {@link GroupedOpenApi} groups, each covering the
 * exact same {@code /**} paths as the plain (English) {@code /v3/api-docs}
 * this class's main {@link #factoryOpenApi} bean already serves, but with a
 * {@link LocalizingOpenApiCustomizer} attached. springdoc builds every
 * group from the same {@code factoryOpenApi}/tags/components baseline
 * before running that group's own customizers, so English stays the one
 * source of truth for every string in the Java annotations; the group
 * customizer only ever swaps already-built text via
 * {@link OpenApiTranslations}, it never generates new content. Swagger UI
 * detects the extra groups automatically and turns the existing top-left
 * "Servers" area into a definition picker (English/default,
 * {@code ru} at {@code /v3/api-docs/ru}, {@code kk} at
 * {@code /v3/api-docs/kk}) — no separate UI work needed. Adding a fourth
 * language later is one more {@code @Bean} plus one more
 * {@code translations_<lang>.json} file, nothing else.
 */
@Configuration
@EnableConfigurationProperties(OpenApiProperties.class)
class OpenApiConfig {

    private static final String BEARER_SECURITY_SCHEME = "bearerAuth";

    @Bean
    OpenAPI factoryOpenApi(OpenApiProperties properties) {
        return new OpenAPI()
                .info(new Info()
                        .title("Factory API")
                        .description("""
                                REST API for Factory — a multi-vertical marketplace platform. \
                                "Factory" is a working codename, not a final product name.

                                Three hardcoded verticals are live so far — Beauty (salons, masters, beauty \
                                bookings), Auto (workshops, mechanics, vehicle bookings), and Cleaning (cleaning \
                                companies, cleaners, cleaning bookings) — plus a generic Staff module usable by a \
                                provider in any category, all built on top of a vertical-agnostic Core (providers, \
                                services, generic bookings, payments, reviews, favorites, search). The category/ \
                                sphere/service taxonomy itself (see the Platform Admin catalog endpoints) is \
                                fully data-driven — new categories don't require a new release.

                                Authentication is a custom JWT bearer scheme (not Spring Security) — obtain a \
                                token from **POST /api/v1/auth/login** or **/api/v1/auth/register**, then use \
                                the Authorize button below with `Bearer <accessToken>` to call endpoints marked \
                                with a lock icon.""")
                        .version("0.1.0"))
                .servers(servers(properties))
                .tags(tags())
                .components(components());
    }

    /**
     * English as its own named group too (identical content to the plain
     * {@code /v3/api-docs}, no customizer) — Swagger UI's "Select a
     * definition" picker only lists named groups, not the default/anonymous
     * document, so without this the picker would only offer ru/kk with no
     * way back to English.
     */
    @Bean
    GroupedOpenApi englishApi() {
        return GroupedOpenApi.builder()
                .group("en")
                .displayName("English")
                .pathsToMatch("/**")
                .build();
    }

    @Bean
    GroupedOpenApi russianApi() {
        return GroupedOpenApi.builder()
                .group("ru")
                .displayName("Русский")
                .pathsToMatch("/**")
                .addOpenApiCustomizer(new LocalizingOpenApiCustomizer(OpenApiTranslations.load("ru")))
                .build();
    }

    @Bean
    GroupedOpenApi kazakhApi() {
        return GroupedOpenApi.builder()
                .group("kk")
                .displayName("Қазақша")
                .pathsToMatch("/**")
                .addOpenApiCustomizer(new LocalizingOpenApiCustomizer(OpenApiTranslations.load("kk")))
                .build();
    }

    /**
     * The reusable {@code ApiError}-shaped responses every endpoint's
     * {@code @ApiResponse(responseCode = "...", ref = "...")} points at
     * instead of redeclaring the same schema+example ~55 times — see
     * {@link ApiError}'s doc comment for why every failure in this API
     * shares this one shape.
     */
    private static Components components() {
        Components components = new Components()
                .addSecuritySchemes(BEARER_SECURITY_SCHEME, new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")
                        .description("""
                                Paste the access token returned by /auth/login or /auth/register \
                                (without the "Bearer " prefix — Swagger UI adds it)."""));

        ResolvedSchema resolved = ModelConverters.getInstance()
                .resolveAsResolvedSchema(new AnnotatedType(ApiError.class));
        components.addSchemas("ApiError", resolved.schema);
        resolved.referencedSchemas.forEach(components::addSchemas);

        addErrorResponse(components, "BadRequest",
                "Malformed request — missing/invalid field, bad JSON, or a query parameter of the wrong type. "
                        + "`errors` is populated for a field-level validation failure, absent otherwise.",
                ApiError.of(400, "Bad Request", "Validation failed", "/api/v1/example"));
        addErrorResponse(components, "Unauthorized",
                "Missing or invalid access token — the Authorization header is absent, malformed, or the token "
                        + "is expired/invalid. Open Authorize (top right) and paste a token from /auth/login.",
                ApiError.of(401, "Unauthorized", "Missing or invalid access token", "/api/v1/example"));
        addErrorResponse(components, "Forbidden",
                "Authenticated, but not allowed to perform this action (e.g. not the resource's owner, or not "
                        + "ADMIN).",
                ApiError.of(403, "Forbidden", "You do not own this resource", "/api/v1/example"));
        addErrorResponse(components, "NotFound", "No resource exists with the given id.",
                ApiError.of(404, "Not Found", "Resource not found", "/api/v1/example"));
        addErrorResponse(components, "Conflict",
                "The request is well-formed but conflicts with the resource's current state (e.g. the slot was "
                        + "already booked, or this email is already registered).",
                ApiError.of(409, "Conflict", "Resource already exists or is in a conflicting state",
                        "/api/v1/example"));
        addErrorResponse(components, "ServerError", "An unexpected failure — not something the caller did.",
                ApiError.of(500, "Internal Server Error", "Something went wrong", "/api/v1/example"));

        return components;
    }

    private static void addErrorResponse(Components components, String name, String description, ApiError example) {
        components.addResponses(name, new ApiResponse()
                .description(description)
                .content(new Content().addMediaType("application/json", new MediaType()
                        .schema(new Schema<>().$ref("#/components/schemas/ApiError"))
                        .addExamples(name, new Example().value(example)))));
    }

    private static List<Server> servers(OpenApiProperties properties) {
        if (properties.servers() == null || properties.servers().isEmpty()) {
            return List.of();
        }
        return properties.servers().stream()
                .map(entry -> new Server().url(entry.url()).description(entry.description()))
                .toList();
    }

    private static List<Tag> tags() {
        return List.of(
                new Tag().name("Authentication")
                        .description("Register, log in, refresh tokens, and reset a forgotten password."),
                new Tag().name("Users").description("Low-level user records. Most apps go through Authentication "
                        + "instead — see each endpoint's description for why these exist separately."),
                new Tag().name("Providers").description(
                        "Generic marketplace listings (a salon, a workshop — vertical-agnostic) and their "
                                + "moderation lifecycle (PENDING -> ACTIVE/SUSPENDED)."),
                new Tag().name("Services").description("What a Provider offers, with a price and duration."),
                new Tag().name("Availability")
                        .description("The time slots a Provider can be booked into, including generating a "
                                + "recurring weekly schedule."),
                new Tag().name("Bookings").description(
                        "Reserving a Service at an Availability slot, and the booking lifecycle "
                                + "(PENDING -> CONFIRMED -> COMPLETED, or CANCELLED)."),
                new Tag().name("Payments").description("Charging and refunding a booking."),
                new Tag().name("Subscriptions").description(
                        "The provider owner's tariff plan (FREE/PRO): usage limits and the recurring charge "
                                + "cycle against the payment provider."),
                new Tag().name("Reviews").description("A rating and comment left on a completed booking."),
                new Tag().name("Favorites").description("A user's saved/bookmarked providers."),
                new Tag().name("Search").description("Customer-facing provider discovery — filters to ACTIVE "
                        + "providers only, unlike the raw Providers listing."),
                new Tag().name("Storage").description("File upload/download backing photos (portfolio images, "
                        + "etc.) — stored in MinIO locally."),
                new Tag().name("Country").description("Countries this platform currently operates in."),
                new Tag().name("Beauty — Masters").description(
                        "Beauty-vertical staff directory: masters, their portfolio photos, and which Services "
                                + "each one performs."),
                new Tag().name("Beauty — Bookings").description(
                        "Beauty-vertical booking: like a generic Booking, but also names which Master performs "
                                + "it, and enforces that the master actually offers the requested Service."),
                new Tag().name("Auto — Mechanics").description(
                        "Auto-vertical staff directory: mechanics and which Services each one performs."),
                new Tag().name("Auto — Vehicles").description(
                        "A customer's registered vehicles — owned by a User, not a Provider."),
                new Tag().name("Auto — Bookings").description(
                        "Auto-vertical booking: like a generic Booking, but also names which Mechanic performs "
                                + "it and which Vehicle it's for, and enforces that the mechanic actually offers "
                                + "the requested Service and the vehicle belongs to the booking's own user."),
                new Tag().name("Cleaning — Cleaners").description(
                        "Cleaning-vertical staff directory: cleaners and which Services each one performs."),
                new Tag().name("Cleaning — Bookings").description(
                        "Cleaning-vertical booking: like a generic Booking, but also names which Cleaner "
                                + "performs it, and enforces that the cleaner actually offers the requested "
                                + "Service."),
                new Tag().name("Staff").description(
                        "Generic, category-agnostic staff directory: works for a provider in any category, "
                                + "not just Beauty/Auto/Cleaning — the platform's path away from hardcoding a "
                                + "new module per vertical."),
                new Tag().name("Staff — Bookings").description(
                        "Staff booking: like a generic Booking, but also names which Staff member performs "
                                + "it, and enforces that the staff member actually offers the requested "
                                + "Service."),
                new Tag().name("Staff — owner").description(
                        "The business owner's side of staff-related appointments: what needs a decision, and "
                                + "cancelling with a refund (only the owner can)."),
                new Tag().name("Staff cabinet").description(
                        "The signed-in staff member's own cabinet: every business they work at, their own "
                                + "appointments there (accept / cancel / complete / no-show) and their rating."));
        // Actuator (health/info, GET /actuator/health) is deliberately not
        // listed here or exposed through Swagger — springdoc.show-actuator
        // is off (see application.yml). It's a platform/ops endpoint, not
        // part of the business API surface this document describes.
    }
}
