# Decidoo Production Completion Matrix

## Implemented in the repository

- Flutter Android/iOS application shell
- Multi-language and RTL infrastructure
- Explainable recommendation engine
- Monetization domain model and Revenue Hub
- Store metadata, privacy policy and release runbook
- Android APK/AAB and unsigned iOS release CI
- Environment-safe build configuration
- Provider-independent authentication, user data, payments, notification, location and restaurant contracts
- Analytics and crash-reporting contracts
- Configuration regression tests

## Integration-ready but requires external accounts

The contracts are intentionally provider-independent. Complete exactly one approved implementation per capability:

- Auth and database: Firebase or Supabase production project
- Premium: Apple StoreKit and Google Play Billing product identifiers
- Payments for restaurant services: server-side Stripe or regional PSP
- Push: APNs and Firebase Cloud Messaging credentials
- Maps/location: Apple/Google/Mapbox account and privacy declarations
- Crash reporting and analytics: approved SDK, consent and retention configuration
- Restaurant catalogue: licensed data source or direct merchant onboarding

## Non-negotiable production gates

- Never store service keys, signing keys or payment secrets in Dart code
- All production API traffic must use HTTPS
- Payments and entitlements must be verified server-side
- Account deletion must remove server data and revoke tokens
- Sponsored recommendations must remain labelled and consent-gated
- Location must be opt-in and the app must remain usable without it
- Health or allergy recommendations must not claim medical diagnosis
- CI, Android physical-device smoke test and TestFlight smoke test must pass
- Privacy policy and store declarations must match the exact enabled SDKs

## Definition of done for each external integration

1. Sandbox and production environments are separated.
2. Secrets exist only in encrypted CI/backend stores.
3. Unit, integration and failure-path tests are present.
4. Offline, timeout, permission-denied and account-deletion behavior is verified.
5. Analytics contains no raw sensitive personal data.
6. Store disclosure documents are updated before release.
