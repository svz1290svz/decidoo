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

## Initial endpoints

- `GET /health` — deployment health check.
- `GET /v1` — API identity and version.

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
- Sponsored influence must never bypass dietary, allergy, availability, budget, or distance constraints.
