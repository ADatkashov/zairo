# Builds platform-api's bootJar (the one runnable module — it pulls every
# bounded-context module in as a dependency, see its build.gradle.kts) into
# a small runtime image. Used by any Docker-based host (Render, Cloud Run,
# Fly.io, a plain VPS) — see docs/ci-cd.md's "Running the backend in the
# cloud" section for how each of those actually uses this file.
#
# Build context is this backend/ directory (the Gradle root) — needed
# because platform-api depends on every sibling module via project(":...").

FROM eclipse-temurin:21-jdk AS build
WORKDIR /workspace
COPY . .
RUN chmod +x gradlew && ./gradlew :platform-api:bootJar --no-daemon
# Spring Boot's Gradle plugin also leaves a classes-only "-plain.jar" next
# to the real executable jar (see build-artifacts.yml's identical note) —
# pick the one that isn't that, whatever its version-derived name is.
RUN set -eu; \
    jar=$(find platform-api/build/libs -maxdepth 1 -name '*.jar' ! -name '*-plain.jar'); \
    cp "$jar" /workspace/app.jar

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /workspace/app.jar app.jar
EXPOSE 8080
# MaxRAMPercentage (not a fixed -Xmx) so the heap sizes itself to whatever
# memory limit the host actually gives the container (512MB on a free-tier
# Render/Cloud Run instance is common) instead of assuming a fixed amount.
ENTRYPOINT ["sh", "-c", "exec java -XX:MaxRAMPercentage=75 -jar app.jar"]
