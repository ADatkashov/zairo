package com.zairo.factory.storage;

import com.zairo.factory.auth.CurrentUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

/** Download stays public (a photo URL embedded elsewhere must load without a token); upload requires any
 * authenticated caller. */
@RestController
@Tag(name = "Storage")
public class StorageController {

    private final StorageService storageService;

    public StorageController(StorageService storageService) {
        this.storageService = storageService;
    }

    public record UploadResponse(
            @Schema(description = "The storage key — pass this straight into GET /uploads/{key} to fetch it "
                    + "back, or into a portfolio/photo request field like MasterDtos.AddPortfolioItemRequest.imageUrl.",
                    example = "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d.jpg")
            String key,
            @Schema(description = "Fully-qualified download URL, built from the request's own host — same "
                    + "as calling GET /uploads/{key} on whichever host this response came from.",
                    example = "http://localhost:8080/api/v1/uploads/a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d.jpg")
            String url) {
    }

    @Operation(summary = "Upload a file", description = "Stores any file in MinIO (S3-compatible) and returns "
            + "a key you can pass to GET /uploads/{key} or embed as a photo URL elsewhere (e.g. a master's "
            + "portfolio). No MIME-type restriction — max size is 10MB (`spring.servlet.multipart.max-file-size`). "
            + "Requires a valid access token — any authenticated user, no ownership check against the file "
            + "itself (it isn't tied to a resource until you pass its key/URL somewhere else, e.g. a "
            + "portfolio item, which is checked there).")
    @ApiResponse(responseCode = "201", description = "Uploaded")
    @ApiResponse(responseCode = "400", description = "The file field is missing or empty.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @io.swagger.v3.oas.annotations.parameters.RequestBody(required = true,
            content = @Content(mediaType = MediaType.MULTIPART_FORM_DATA_VALUE,
                    schema = @Schema(type = "object", requiredProperties = "file")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping(value = "/api/v1/uploads", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public UploadResponse upload(@Parameter(description = "The file to upload.", schema = @Schema(type = "string",
            format = "binary")) @RequestParam MultipartFile file, HttpServletRequest request) {
        CurrentUser.requireUserId(request);
        if (file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "File is empty");
        }
        String key = storageService.upload(file);
        String baseUrl = request.getScheme() + "://" + request.getServerName() + ":" + request.getServerPort();
        return new UploadResponse(key, baseUrl + "/api/v1/uploads/" + key);
    }

    @Operation(summary = "Download a file", description = "Streams the raw file bytes back with its original "
            + "Content-Type — this is what a photo URL returned elsewhere in the API (e.g. a portfolio "
            + "item's imageUrl) ultimately points at.")
    @ApiResponse(responseCode = "200", description = "The file's raw bytes",
            content = @Content(mediaType = "application/octet-stream",
                    schema = @Schema(type = "string", format = "binary")))
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "No file with this key.")
    @GetMapping("/api/v1/uploads/{key}")
    public ResponseEntity<InputStreamResource> download(
            @Parameter(description = "The storage key returned by POST /uploads.") @PathVariable String key)
            throws IOException {
        StorageService.DownloadedFile file = storageService.download(key);
        MediaType mediaType = file.contentType() != null ? MediaType.parseMediaType(file.contentType())
                : MediaType.APPLICATION_OCTET_STREAM;
        return ResponseEntity.ok().contentType(mediaType).body(new InputStreamResource(file.content()));
    }
}
