package com.zairo.factory.storage;

import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.io.InputStream;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpHeaders;
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

@RestController
public class StorageController {

    private final StorageService storageService;

    public StorageController(StorageService storageService) {
        this.storageService = storageService;
    }

    public record UploadResponse(String key, String url) {
    }

    @PostMapping("/api/v1/uploads")
    @ResponseStatus(HttpStatus.CREATED)
    public UploadResponse upload(@RequestParam MultipartFile file, HttpServletRequest request) {
        if (file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "File is empty");
        }
        String key = storageService.upload(file);
        String baseUrl = request.getScheme() + "://" + request.getServerName() + ":" + request.getServerPort();
        return new UploadResponse(key, baseUrl + "/api/v1/uploads/" + key);
    }

    @GetMapping("/api/v1/uploads/{key}")
    public ResponseEntity<InputStreamResource> download(@PathVariable String key) throws IOException {
        StorageService.DownloadedFile file = storageService.download(key);
        MediaType mediaType = file.contentType() != null ? MediaType.parseMediaType(file.contentType())
                : MediaType.APPLICATION_OCTET_STREAM;
        return ResponseEntity.ok().contentType(mediaType).body(new InputStreamResource(file.content()));
    }
}
