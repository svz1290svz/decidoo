# Decidoo Closed Beta Runbook

## Goal
Run the real Decidoo mobile application against a real HTTPS production-like API with a small invited tester group before public store launch.

## Required external inputs
- A Linux host or managed container service with Docker support
- A real HTTPS API hostname, e.g. `api.example.com`
- DNS + TLS termination/reverse proxy
- Production PostgreSQL credentials or the bundled beta PostgreSQL container
- Strong JWT access/refresh secrets
- 32-byte hex push-token encryption key
- Payment confirmation secret
- Firebase Android/iOS project files for real push notifications
- Google Play internal testing and/or Apple TestFlight credentials for store-distributed beta

## Backend deployment
1. Copy `deploy/docker-compose.beta.yml` to the host together with the repository.
2. Provide secrets through the host secret manager or an untracked environment file.
3. Start with `docker compose -f deploy/docker-compose.beta.yml up -d --build`.
4. Put an HTTPS reverse proxy or cloud load balancer in front of `127.0.0.1:8080`.
5. Run `API_BASE_URL=https://your-api-host bash tool/beta_smoke_test.sh`.
6. Confirm database backups before adding beta users.

The backend container applies Prisma migrations before starting the API.

## GitHub mobile configuration
Set repository variable `PRODUCTION_API_BASE_URL` to the real HTTPS API URL. Do not use `.invalid`, localhost, `10.0.2.2`, or a private LAN address.

For a tagged `v*` release, the store workflow disables demo mode and injects the production API URL. PR builds remain validation/demo builds and must not be distributed as production.

## Closed beta acceptance flow
Every invited tester should complete: account registration, sign-in, session refresh, food recommendation, restaurant detail, navigation action, favorite add/remove, language change, offline reopen, reconnect/sync, push permission, account deletion, and fresh registration after deletion.

Restaurant-owner acceptance should cover: restaurant creation, menu/category/meal management, operating hours, moderation submission, Monetization Hub, campaign creation, payment-reference generation, pause/cancel, and ROI display.

Admin acceptance should cover moderation, KPI dashboard and audit records.

## Monetization safety
Do not connect live charging until the payment provider webhook adapter validates the provider's native signature and maps verified events to Decidoo's internal payment confirmation endpoint. Boost and Smart campaigns are additionally protected at database level from activation without matching paid funding. Per-action remains postpaid by design.

## Exit criteria for public launch
- No P0/P1 defects from closed beta
- Production API health and readiness stable
- Database backup/restore drill completed
- Crash/error monitoring connected
- Firebase push verified on Android and iOS physical devices
- Payment provider sandbox end-to-end tests passed
- Privacy policy and store disclosures match actual production data behavior
- Google Play internal testing and TestFlight smoke tests passed
