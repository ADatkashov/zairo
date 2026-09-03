package com.zairo.factory.storage;

import io.minio.GetObjectArgs;
import io.minio.GetObjectResponse;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@Service
public class StorageService {

    private final MinioClient minioClient;
    private final String bucket;

    public StorageService(MinioClient minioClient, StorageProperties properties) {
        this.minioClient = minioClient;
        this.bucket = properties.bucket();
    }

    /** Returns the object key the file was stored under — a random UUID plus an extension derived from the
     * file's own detected type, never the client-supplied filename/Content-Type (see DetectedImageType's doc
     * comment for why: both are attacker-controlled). Only JPEG/PNG/WebP are accepted — the only formats
     * cover photos and portfolio images actually need. */
    public String upload(MultipartFile file) {
        byte[] content;
        try {
            content = file.getBytes();
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Failed to read file: " + e.getMessage());
        }
        DetectedImageType type = DetectedImageType.detect(content).orElseThrow(() -> new ResponseStatusException(
                HttpStatus.BAD_REQUEST, "Unsupported file type — only JPEG, PNG, and WebP images are allowed."));
        String key = UUID.randomUUID() + type.extension;
        try (InputStream in = new ByteArrayInputStream(content)) {
            minioClient.putObject(PutObjectArgs.builder().bucket(bucket).object(key)
                    .stream(in, (long) content.length, -1L).contentType(type.contentType).build());
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Failed to store file: " + e.getMessage());
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Failed to store file: " + e.getMessage());
        }
        return key;
    }

    public record DownloadedFile(InputStream content, String contentType) {
    }

    /** contentType is re-validated against the same JPEG/PNG/WebP allowlist upload enforces (null if it
     * doesn't match) rather than trusted as-is — a defense-in-depth backstop for any object stored before
     * this validation existed, not just newly uploaded ones. The controller falls back to
     * application/octet-stream whenever this comes back null. */
    public DownloadedFile download(String key) {
        try {
            GetObjectResponse response = minioClient
                    .getObject(GetObjectArgs.builder().bucket(bucket).object(key).build());
            String storedContentType = response.headers().get("Content-Type");
            String trustedContentType = DetectedImageType.forContentType(storedContentType)
                    .map(type -> type.contentType).orElse(null);
            return new DownloadedFile(response, trustedContentType);
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "File not found: " + key);
        }
    }
}
