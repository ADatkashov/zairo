# ZAIRO platform console

The staff tool for running the marketplace: moderating businesses, managing the
catalog (categories → spheres → subspheres → services) and cities, settling
payouts and refunds, reading the activity log and managing staff accounts.

Runs on web, Android, iOS, Windows, macOS and Linux from one code base. Full
description — what it does per role, how to deploy it, what the backend still
lacks — in [`docs/PLATFORM_ADMIN_APP.md`](../../docs/PLATFORM_ADMIN_APP.md).

```bash
flutter run -d chrome                                   # local backend on :8080
flutter run -d chrome --dart-define=API_BASE_URL=https://api.example.com/api/v1
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

The backend must list the console's origin in `CORS_ALLOWED_ORIGINS`.
