# Decidoo Global Release Readiness

## Code-ready capabilities

- Secure authentication and token renewal
- Personalized hybrid recommendation ranking
- Favorites, recent searches and preference APIs
- Restaurant-owner and administrator workflows
- Encrypted offline cache with outage fallback
- Push-device registration and revocation contract
- Health and readiness probes
- Redacted structured logging and request identifiers
- Admin KPI dashboard and moderation audit records
- Android and iOS CI release validation
- API load-test profile

## External launch inputs

Before public release, connect the production API address, Firebase project, mobile signing credentials, managed PostgreSQL, public support/privacy pages and an error-report collector. These are deployment-account inputs; the integration points are already present in the repository.

## Scale deployment

Run the stateless API behind a load balancer with multiple replicas. Use managed PostgreSQL with backups and connection pooling, object storage for media, edge rate limiting, a delivery queue for notifications, and centralized logs and alerts.

The local rate limiter is a per-instance safety fallback. Global limits should be enforced at the edge when multiple API replicas are used.

## Initial service objectives

- Monthly API availability: 99.9%
- Recommendation p95 latency: below 500 ms
- Recommendation p99 latency: below 1.2 seconds
- Server error rate: below 1%
- Crash-free mobile sessions: above 99.5%
- Backups tested through regular restore exercises

## Release sequence

1. Provision the production database and apply migrations.
2. Deploy the API and verify health and readiness endpoints.
3. Run the included load test against production-like data.
4. Connect Firebase and pass the messaging token to the push registration service.
5. Add signing and release configuration to GitHub.
6. Create a version tag and download CI artifacts.
7. Publish to internal testing tracks before public rollout.

## Capacity statement

The codebase supports horizontal scaling, but real million-user capacity must be proven with production traffic tests, infrastructure sizing and measured observability data. The included load test and service objectives provide that measurable path.
