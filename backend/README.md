# backend/

Spring Boot 4.1, modular monolith, один деплой-юнит. Gradle multi-module по
bounded context: `auth`, `users`, `providers`, `services`, `booking`,
`payments`, `reviews`, `notifications`, `search` — сейчас пустые
(`package-info.java` с описанием границы), логика появится в Phase 2.

`platform-api` — единственный запускаемый модуль, собирает остальные в один
процесс.

```
cd backend
./gradlew bootRun            # http://localhost:8080/actuator/health
./gradlew test
```

Локальные Postgres/Redis/MinIO — через `../infrastructure/docker-compose.yml`.
