# Decidoo Store Release Runbook

## Release identity

- Product name: Decidoo
- Android application ID: `com.decidoo.decidoo`
- iOS bundle ID: `com.decidoo.decidoo`
- Primary category: Food & Drink
- Secondary category: Lifestyle

## Automated quality gates

A release candidate is accepted only when all of the following pass:

- Dart formatting
- Flutter static analysis
- Unit and widget tests
- Android release APK build
- Android release AAB build
- iOS release build without code signing
- Secret scan/release preflight
- Store metadata and privacy-policy presence checks

A Git tag matching `v*` is treated as a production release and MUST have a real HTTPS `PRODUCTION_API_BASE_URL`. Placeholder `.invalid` addresses are rejected. Pull-request artifacts are validation/demo artifacts and must never be submitted to an app store as production builds.

## Google Play Console configuration

### App access

The production service supports authenticated accounts. If Google Play review cannot access all reviewable functionality without an account, provide a valid review account and clear access instructions in Play Console.

### Data Safety

Do **not** select `Data collected: No` for the production connected application. Complete Google Play Data Safety based on the exact services enabled in the submitted build. Expected categories may include:

- account/personal information such as email and display name;
- app activity such as favorites, recommendations and interaction history;
- location when the user grants permission;
- device identifiers or push tokens used for notifications;
- diagnostics required for crash/error reporting when enabled.

The declaration must distinguish required data from optional data and must match actual retention, encryption, deletion and sharing behavior. No advertising ID is required by the current core implementation unless a future advertising SDK introduces it.

### Account deletion

The production application provides an authenticated account-deletion capability backed by `/v1/me/account`. Google Play's account deletion declarations and any required web deletion URL must point to the final production support/privacy surface.

### Release artifact

Upload only a properly signed production `app-release.aab` produced with the real HTTPS API configuration. Validation/demo AABs or debug-signed artifacts must not be submitted.

## App Store Connect configuration

### App Privacy

Do **not** select `Data Not Collected` for the connected production service. App Privacy answers must match the exact enabled production functionality, including account data, personalization activity, optional location, push notification identifiers and diagnostics where applicable.

### Review information

- Login may be required for connected account features.
- Provide a stable reviewer account if Apple cannot evaluate required functionality without one.
- Location is optional and used for nearby/distance-based recommendations when permission is granted.
- Notifications are optional and require platform permission.
- Tracking permission is not required unless a future SDK performs cross-app/site tracking.

### Build requirements

The final App Store archive must be built with the App Store-required Xcode/iOS SDK and signed with valid Apple distribution credentials. The unsigned CI artifact is validation-only.

## Production behavior that store declarations must cover

- account registration, login, refresh-token sessions and password reset;
- user profile and preferred language;
- food preferences, budgets, distance settings and personalization;
- favorites and recommendation interaction history;
- optional device location;
- optional push notifications;
- restaurant owner/admin management data;
- security/audit logs and configured diagnostics;
- account deletion and privacy-request workflows.

## Required private credentials and external configuration

These must never be committed to GitHub:

### Backend / shared

- production database URL
- JWT secrets
- push-token encryption key
- production API domain/HTTPS deployment
- email delivery credentials
- Firebase/APNs configuration where notifications are enabled
- approved error-reporting endpoint and credentials where enabled

### Android

- production upload keystore
- keystore password
- key alias and key password
- Google Play service-account credentials if automated upload is enabled

### Apple

- Apple Developer Team ID
- App Store Connect issuer ID and key ID
- App Store Connect API private key
- distribution certificate/provisioning credentials as applicable

## Visual and legal assets requiring account-owner approval

- final application icons
- Google Play feature graphic
- current phone/tablet screenshots of the exact submitted build
- stable HTTPS privacy-policy URL
- stable HTTPS support URL
- final store descriptions and localization

## Manual release sequence

1. Deploy the production backend and database.
2. Publish the privacy policy and support page at stable HTTPS URLs.
3. Set repository variable `PRODUCTION_API_BASE_URL` to the real production HTTPS API.
4. Configure Firebase/APNs, email, signing and remaining production secrets.
5. Run backend smoke tests against the production/staging environment.
6. Create a tagged release only after the production API health/readiness endpoints pass.
7. Install the resulting signed Android build on a physical device and test registration/login, recommendation, location-denied/location-granted behavior, favorites, language changes, offline recovery, logout/login and account deletion.
8. Upload the signed AAB to Google Play internal testing and run another physical-device smoke test.
9. Upload the signed iOS build to TestFlight and run the same smoke test on iPhone.
10. Complete Google Play Data Safety and Apple App Privacy using the exact submitted functionality.
11. Submit only when store declarations, privacy policy and runtime behavior match.

## Release blockers

Do not submit while any of these are unresolved:

- missing or unreachable production HTTPS API;
- placeholder API URL inside the build;
- missing production signing credentials;
- privacy/store disclosures inconsistent with actual account, location, notification or diagnostics behavior;
- account deletion not verified end-to-end;
- missing final privacy/support URLs;
- a required CI job is not green;
- Android physical-device and iOS TestFlight smoke tests have not passed.
