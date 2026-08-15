# Physical-device Android builds

A Decidoo APK intended for a real Android phone must be compiled with a reachable HTTPS API URL:

```bash
flutter build apk --debug --dart-define=API_BASE_URL=https://<your-live-api-host>
```

The default `http://10.0.2.2:3000` address is emulator-only and must never be used for a physical-device beta.

Before distributing an APK, verify:

1. `GET <API_BASE_URL>/health` returns HTTP 200.
2. Register and login succeed against the same database.
3. The APK was built with that exact `API_BASE_URL`.

Production backend startup also requires `PUSH_TOKEN_ENCRYPTION_KEY` (64 hex chars) and `PAYMENT_CONFIRMATION_SECRET` (minimum 32 chars).
