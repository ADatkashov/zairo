description = "Generic file storage (S3-compatible, via MinIO in dev) — portfolio photos and other user-uploaded media. Not vertical-specific."

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("io.minio:minio:9.0.3")
}
