description = "Generic file storage (S3-compatible, via MinIO in dev) — portfolio photos and other user-uploaded media. Not vertical-specific."

dependencies {
    compileOnly("io.swagger.core.v3:swagger-annotations-jakarta:2.2.38")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("io.minio:minio:9.0.3")
}
