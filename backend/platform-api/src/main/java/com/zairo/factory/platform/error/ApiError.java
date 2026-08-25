package com.zairo.factory.platform.error;

import java.time.Instant;
import java.util.Map;

/**
 * The one error shape every endpoint in this API returns for a non-2xx
 * response — added alongside the OpenAPI/Swagger documentation effort
 * because there was no unified error model to document (every failure
 * fell through to Spring Boot's bare default {@code {timestamp, status,
 * error, path}} body, with malformed requests surfacing as an undocumented
 * 500 instead of a 400 — see GlobalExceptionHandler). {@code errors} is
 * only populated for validation failures (field name -> human message);
 * every other failure leaves it {@code null}.
 */
public record ApiError(
        Instant timestamp,
        int status,
        String error,
        String message,
        String path,
        Map<String, String> errors) {

    public static ApiError of(int status, String error, String message, String path) {
        return new ApiError(Instant.now(), status, error, message, path, null);
    }

    public static ApiError validation(String path, Map<String, String> errors) {
        return new ApiError(Instant.now(), 400, "Bad Request", "Validation failed", path, errors);
    }
}
