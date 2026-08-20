package com.zairo.factory.storage;

import io.minio.GetObjectArgs;
import io.minio.GetObjectResponse;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
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

    /** Returns the object key the file was stored under — a random UUID, original filename is not preserved. */
    public String upload(MultipartFile file) {
        String extension = extensionOf(file.getOriginalFilename());
        String key = UUID.randomUUID() + extension;
        try (InputStream in = file.getInputStream()) {
            minioClient.putObject(PutObjectArgs.builder().bucket(bucket).object(key).stream(in, file.getSize(), -1L)
                    .contentType(file.getContentType()).build());
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Failed to store file: " + e.getMessage());
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Failed to store file: " + e.getMessage());
        }
        return key;
    }

    public record DownloadedFile(InputStream content, String contentType) {
    }

    public DownloadedFile download(String key) {
        try {
            GetObjectResponse response = minioClient
                    .getObject(GetObjectArgs.builder().bucket(bucket).object(key).build());
            String contentType = response.headers().get("Content-Type");
            return new DownloadedFile(response, contentType);
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "File not found: " + key);
        }
    }

    private static String extensionOf(String originalFilename) {
        if (originalFilename == null) {
            return "";
        }
        int dot = originalFilename.lastIndexOf('.');
        return dot >= 0 ? originalFilename.substring(dot) : "";
    }
}
