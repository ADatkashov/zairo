package com.zairo.factory.platform.openapi;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.io.InputStream;
import java.util.Map;
import org.springframework.core.io.ClassPathResource;

/**
 * Loads one language's English-text -> translated-text lookup table from
 * {@code resources/openapi/translations_<lang>.json}. English itself needs
 * no file — it's already the literal text every {@code @Operation}/
 * {@code @Parameter}/{@code @ApiResponse}/{@code @Tag} annotation carries,
 * so the "en" case is the identity mapping (see
 * {@link LocalizingOpenApiCustomizer#IDENTITY}).
 *
 * <p>JSON, not {@code .properties}: the values are full sentences with
 * punctuation, backticks, and markdown — {@code .properties} key/value
 * escaping for that is fragile, and JSON has no such restriction. The key
 * is the English source string itself (a "gettext" style catalog) rather
 * than an invented short key like {@code auth.register.summary} — this
 * way the controller/DTO annotations stay exactly as readable as ordinary
 * English Javadoc, and a translation with no corresponding source text
 * (or vice versa) is a silent no-op instead of a compile error, which is
 * the right failure mode for documentation text.
 */
final class OpenApiTranslations {

    private OpenApiTranslations() {
    }

    static Map<String, String> load(String languageTag) {
        String path = "openapi/translations_" + languageTag + ".json";
        try (InputStream in = new ClassPathResource(path).getInputStream()) {
            return new ObjectMapper().readValue(in, new TypeReference<Map<String, String>>() {
            });
        } catch (IOException e) {
            throw new IllegalStateException("Could not load OpenAPI translations from " + path, e);
        }
    }
}
