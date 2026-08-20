package com.zairo.factory.storage;

import io.minio.BucketExistsArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(StorageProperties.class)
public class StorageConfig {

    private static final Logger log = LoggerFactory.getLogger(StorageConfig.class);

    @Bean
    public MinioClient minioClient(StorageProperties properties) {
        MinioClient client = MinioClient.builder().endpoint(properties.endpoint())
                .credentials(properties.accessKey(), properties.secretKey()).build();
        ensureBucketExists(client, properties.bucket());
        return client;
    }

    /**
     * Dev convenience: the bucket doesn't exist on a fresh `docker compose
     * up` until something creates it. A real deployment would provision the
     * bucket as part of infra setup, not on every app boot.
     *
     * Deliberately non-fatal: MinIO isn't Testcontainerized (see
     * StorageApiTests' javadoc), so every other *ApiTests class would fail
     * to even start a Spring context if this threw when MinIO happens not
     * to be running — a failure that has nothing to do with what those
     * tests actually exercise. Storage calls fail on their own, clearly,
     * if MinIO genuinely isn't reachable when someone tries to upload.
     */
    private void ensureBucketExists(MinioClient client, String bucket) {
        try {
            boolean exists = client.bucketExists(BucketExistsArgs.builder().bucket(bucket).build());
            if (!exists) {
                client.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
                log.info("Created storage bucket: {}", bucket);
            }
        } catch (Exception e) {
            log.warn("Could not prepare storage bucket '{}' — is MinIO running? Uploads will fail until it is: {}",
                    bucket, e.getMessage());
        }
    }
}
