# Decidoo Backend

Production-oriented API foundation for Decidoo's consumer app, restaurant panel, recommendation engine, and monetization services.

## Local setup

1. Install Node.js 20+ and PostgreSQL.
2. Copy `.env.example` to `.env` and replace all secrets.
3. Run `npm install`.
4. Run `npm run prisma:generate`.
5. Run `npm run prisma:migrate -- --name init`.
6. Run `npm run dev`.

The API starts on `http://localhost:8080` by default.

## Endpoints

- `GET /health` — API and PostgreSQL health check.
- `GET /v1` — API identity and version.
- `POST /v1/auth/register` — create a consumer account and session.
- `POST /v1/auth/login` — authenticate with email and password.
- `POST /v1/auth/refresh` — rotate a refresh token and issue a new session.
- `POST /v1/auth/logout` — revoke the submitted refresh token.
- `GET /v1/me` — return the authenticated user for a Bearer access token.

## Authentication contract

Registration accepts `email`, `password`, optional `displayName`, and `preferredLanguage` (`tr` or `en`). Passwords require at least 10 characters and are stored with bcrypt cost 12. Access tokens are short-lived JWTs. Refresh tokens are rotated on every use, and only SHA-256 hashes are stored in PostgreSQL.

The mobile client must keep refresh tokens in Android Keystore or iOS Keychain. Access tokens should remain in memory and be renewed through `/v1/auth/refresh`.

## Data domains

The initial Prisma schema covers:

- consumer, restaurant owner, staff, and admin identities;
- user dietary, budget, distance, and cuisine preferences;
- restaurants, menus, dishes, allergens, and availability;
- recommendation sessions, ranking reasons, actions, and algorithm versions;
- clearly disclosed sponsored placement and boost attribution;
- payment transaction records and hashed refresh-token sessions.

## Security rules

- Never commit `.env`.
- Use unique access and refresh secrets with at least 32 random characters.
- Store only hashed refresh tokens.
- Return the same login error for an unknown account and an invalid password.
- Rotate refresh tokens and revoke the previous token after every successful refresh.
- Sponsored influence must never bypass dietary, allergy, availability, budget, or distance constraints.
