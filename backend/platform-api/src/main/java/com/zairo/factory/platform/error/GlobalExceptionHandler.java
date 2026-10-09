package com.zairo.factory.platform.error;

import jakarta.servlet.http.HttpServletRequest;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpMediaTypeNotAcceptableException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/**
 * The single place every exception this API can throw turns into an
 * {@link ApiError} body. Before this existed, every failure fell through to
 * Spring Boot's bare default error body — no {@code message}, and a
 * malformed request body surfaced as an undocumented 500 instead of a 400
 * (there was no {@code @Valid}/bean-validation anywhere in the codebase;
 * see the request DTOs, which now carry {@code jakarta.validation}
 * annotations specifically so this handler has something to report).
 *
 * <p>Every domain exception in this codebase is either a
 * {@link ResponseStatusException} or a plain {@link RuntimeException}
 * annotated with Spring's {@code @ResponseStatus} (e.g.
 * {@code EmailAlreadyRegisteredException}) — both are handled generically
 * below without needing a case per exception type, so a new bounded-context
 * module doesn't need to touch this class to get a correct error body.
 */
@RestControllerAdvice
class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        Map<String, String> errors = new LinkedHashMap<>();
        for (FieldError fieldError : ex.getBindingResult().getFieldErrors()) {
            errors.put(fieldError.getField(),
                    fieldError.getDefaultMessage() != null ? fieldError.getDefaultMessage() : "Invalid value");
        }
        return ResponseEntity.badRequest().body(ApiError.validation(request.getRequestURI(), errors));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ApiError> handleUnreadable(HttpServletRequest request) {
        return ResponseEntity.badRequest()
                .body(ApiError.of(400, "Bad Request", "Malformed or missing request body", request.getRequestURI()));
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    ResponseEntity<ApiError> handleMissingParam(MissingServletRequestParameterException ex, HttpServletRequest request) {
        return ResponseEntity.badRequest().body(ApiError.of(400, "Bad Request",
                "Missing required parameter: " + ex.getParameterName(), request.getRequestURI()));
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    ResponseEntity<ApiError> handleTypeMismatch(MethodArgumentTypeMismatchException ex, HttpServletRequest request) {
        return ResponseEntity.badRequest().body(ApiError.of(400, "Bad Request",
                "Invalid value for parameter: " + ex.getName(), request.getRequestURI()));
    }

    // Spring throws this as a plain RuntimeException with no @ResponseStatus, so without this
    // handler it fell through to handleUnexpected below — an uploaded file over
    // spring.servlet.multipart.max-file-size surfaced to the client as an opaque 500 instead of a
    // clear "too large" error (seen in production against POST /api/v1/uploads).
    @ExceptionHandler(MaxUploadSizeExceededException.class)
    ResponseEntity<ApiError> handleMaxUploadSize(HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE).body(ApiError.of(413, "Payload Too Large",
                "File exceeds the maximum upload size (10MB)", request.getRequestURI()));
    }

    // Spring MVC throws this for any unmatched path — most commonly a
    // browser's unsolicited GET /favicon.ico — as a plain RuntimeException
    // with no @ResponseStatus (its 404 lives on ErrorResponse#getStatusCode
    // instead), so without this handler it fell through all the way to
    // handleUnexpected below: logged at ERROR with a full stack trace and
    // returned to the client as a 500, for what's actually a routine 404.
    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<ApiError> handleNoResource(HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(ApiError.of(404, "Not Found", "No such endpoint or resource", request.getRequestURI()));
    }

    // Like NoResourceFoundException above, Spring MVC throws these three as plain exceptions
    // whose status lives on ErrorResponse#getStatusCode, so they fell through to
    // handleUnexpected and a client that used the wrong HTTP method or Content-Type got an
    // opaque 500 (and an ERROR stack trace in the log) instead of a 405 / 415 / 406.
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    ResponseEntity<ApiError> handleMethodNotSupported(HttpRequestMethodNotSupportedException ex,
            HttpServletRequest request) {
        ResponseEntity.BodyBuilder response = ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED);
        if (ex.getSupportedHttpMethods() != null) {
            response.allow(ex.getSupportedHttpMethods().toArray(new HttpMethod[0]));
        }
        return response.body(ApiError.of(405, "Method Not Allowed",
                "Method " + ex.getMethod() + " is not supported for this endpoint", request.getRequestURI()));
    }

    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    ResponseEntity<ApiError> handleMediaTypeNotSupported(HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.UNSUPPORTED_MEDIA_TYPE).body(ApiError.of(415,
                "Unsupported Media Type", "Content type is not supported — send application/json",
                request.getRequestURI()));
    }

    @ExceptionHandler(HttpMediaTypeNotAcceptableException.class)
    ResponseEntity<ApiError> handleMediaTypeNotAcceptable(HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.NOT_ACCEPTABLE).body(ApiError.of(406, "Not Acceptable",
                "This endpoint can only respond with application/json", request.getRequestURI()));
    }

    @ExceptionHandler(ResponseStatusException.class)
    ResponseEntity<ApiError> handleResponseStatus(ResponseStatusException ex, HttpServletRequest request) {
        HttpStatusCode status = ex.getStatusCode();
        String message = ex.getReason() != null ? ex.getReason() : status.toString();
        return ResponseEntity.status(status)
                .body(ApiError.of(status.value(), reasonPhrase(status), message, request.getRequestURI()));
    }

    @ExceptionHandler(RuntimeException.class)
    ResponseEntity<ApiError> handleRuntime(RuntimeException ex, HttpServletRequest request) {
        ResponseStatus annotation = AnnotatedElementUtils.findMergedAnnotation(ex.getClass(), ResponseStatus.class);
        if (annotation != null) {
            HttpStatus status = annotation.value();
            String message = ex.getMessage() != null ? ex.getMessage() : status.getReasonPhrase();
            return ResponseEntity.status(status)
                    .body(ApiError.of(status.value(), status.getReasonPhrase(), message, request.getRequestURI()));
        }
        return handleUnexpected(ex, request);
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiError> handleUnexpected(Exception ex, HttpServletRequest request) {
        log.error("Unhandled exception on {} {}", request.getMethod(), request.getRequestURI(), ex);
        return ResponseEntity.internalServerError().body(
                ApiError.of(500, "Internal Server Error", "Something went wrong", request.getRequestURI()));
    }

    private static String reasonPhrase(HttpStatusCode status) {
        return HttpStatus.resolve(status.value()) != null ? HttpStatus.resolve(status.value()).getReasonPhrase()
                : status.toString();
    }
}
