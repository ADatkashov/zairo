# infrastructure/

Локальная разработка и CI.

```
docker compose -f infrastructure/docker-compose.yml up -d
```

Поднимает Postgres (`5432`), Redis (`6379`), MinIO S3-совместимое хранилище
(`9000`, консоль на `9001`). `backend/` пока ни с чем из этого не соединён —
подключение (Flyway, datasource) появится в Phase 2 вместе с первыми
доменными сущностями.
