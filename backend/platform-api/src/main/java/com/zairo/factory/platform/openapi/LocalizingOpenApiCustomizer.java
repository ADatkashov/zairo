package com.zairo.factory.platform.openapi;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.responses.ApiResponse;
import java.util.Map;
import org.springdoc.core.customizers.OpenApiCustomizer;

/**
 * Rewrites every human-readable documentation string in an already-built
 * {@link OpenAPI} — tag descriptions, operation summaries/descriptions,
 * parameter descriptions, and named response descriptions — through a
 * translation table, leaving everything else (paths, schemas, field names,
 * example values, enum constants) untouched. This is deliberately the
 * *only* place a request for a language change is handled: the
 * {@code @Operation}/{@code @Parameter}/{@code @ApiResponse}/{@code @Tag}
 * annotations across every controller stay in plain English forever,
 * pointed at from {@link OpenApiConfig}'s per-language
 * {@code GroupedOpenApi} beans (see its class doc comment for the group
 * -> language -> Swagger-UI-picker wiring).
 *
 * <p>Skips any text the translation table has no entry for (returns it
 * unchanged) rather than throwing — a string added to a controller without
 * a matching translation degrades to English for that language instead of
 * breaking the build or the other two languages.
 */
final class LocalizingOpenApiCustomizer implements OpenApiCustomizer {

    private final Map<String, String> translations;

    LocalizingOpenApiCustomizer(Map<String, String> translations) {
        this.translations = translations;
    }

    @Override
    public void customise(OpenAPI openApi) {
        if (openApi.getInfo() != null) {
            openApi.getInfo().setDescription(translate(openApi.getInfo().getDescription()));
        }
        if (openApi.getTags() != null) {
            openApi.getTags().forEach(tag -> tag.setDescription(translate(tag.getDescription())));
        }
        if (openApi.getComponents() != null) {
            if (openApi.getComponents().getSecuritySchemes() != null) {
                openApi.getComponents().getSecuritySchemes().values()
                        .forEach(scheme -> scheme.setDescription(translate(scheme.getDescription())));
            }
            if (openApi.getComponents().getResponses() != null) {
                openApi.getComponents().getResponses().values().forEach(this::translateResponse);
            }
        }
        if (openApi.getPaths() != null) {
            openApi.getPaths().values().forEach(item -> item.readOperations().forEach(this::translateOperation));
        }
    }

    private void translateOperation(Operation operation) {
        operation.setSummary(translate(operation.getSummary()));
        operation.setDescription(translate(operation.getDescription()));
        if (operation.getParameters() != null) {
            operation.getParameters().forEach(p -> p.setDescription(translate(p.getDescription())));
        }
        if (operation.getResponses() != null) {
            operation.getResponses().values().forEach(this::translateResponse);
        }
    }

    /** A pure {@code $ref} response carries no local description — nothing to translate there directly; its target lives in components.responses and is translated once, above. */
    private void translateResponse(ApiResponse response) {
        if (response.get$ref() == null) {
            response.setDescription(translate(response.getDescription()));
        }
    }

    private String translate(String english) {
        if (english == null) {
            return null;
        }
        return translations.getOrDefault(english, english);
    }
}
