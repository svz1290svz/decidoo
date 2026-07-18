# Decidoo 1.0.0 Store Release Runbook

## Release identity

- Product name: Decidoo
- Android application ID: `com.decidoo.decidoo`
- iOS bundle ID: `com.decidoo.decidoo`
- Marketing version: `1.0.0`
- Build number: `1`
- Primary category: Food & Drink
- Secondary category: Lifestyle
- Content rating target: Everyone / 4+

## Automated quality gates

A release candidate is accepted only when all of the following pass:

- Dart formatting
- Flutter static analysis
- Unit tests
- Widget smoke tests
- Android release APK build
- Android release AAB build
- iOS release build without code signing
- Secret scan preflight
- Store metadata presence check
- Privacy policy presence check

## Google Play Console configuration

### App content

- Ads: No ads in version 1.0.0
- App access: All functionality is available without login
- Target audience: General audience; not specifically designed for children
- News app: No
- Government app: No
- Financial features: No
- Health features: No
- Data safety: Complete even though no user data is collected
- Privacy policy: Publish `docs/privacy-policy.md` at a stable HTTPS URL and enter that URL

### Data safety answers for version 1.0.0

- Data collected: No
- Data shared: No
- Data encrypted in transit: Not applicable because no user data is transmitted
- Account deletion: Not applicable because the app has no account system
- Location: Not collected
- Personal information: Not collected
- App activity: Not transmitted
- Device identifiers: Not collected
- Advertising ID: Not used

### Release artifact

Upload the signed `app-release.aab`. Google Play App Signing should be enabled. The unsigned or debug-signed validation artifact from CI must not be submitted as the production bundle.

## App Store Connect configuration

### App privacy answers for version 1.0.0

Select **Data Not Collected**. The application does not transmit preferences, identifiers, analytics, location, purchase data, or diagnostics to a Decidoo server or third-party SDK.

### Review information

- Login required: No
- Demo account: Not required
- Tracking permission: Not requested
- In-app purchases: Not enabled in version 1.0.0
- External purchases: None
- User-generated content: None
- Location features: None

### Build requirements

The final App Store archive must be built on macOS using the current App Store-required Xcode and iOS SDK. A valid Apple Distribution certificate, App Store provisioning profile, Apple Team ID, and App Store Connect API credentials are required for upload.

## Required private credentials

These values must never be committed to GitHub:

### Android

- Production upload keystore file
- Keystore password
- Key alias
- Key password
- Google Play service-account JSON, only if automated upload is enabled

### Apple

- Apple Developer Team ID
- App Store Connect issuer ID
- App Store Connect key ID
- App Store Connect API private key
- Distribution certificate and password, if certificate-based signing is used
- Provisioning profile, if automatic signing is not used

Store these values in GitHub Actions secrets or in the CI provider's encrypted credential store.

## Visual assets still requiring account-owner approval

- 1024 × 1024 App Store icon without transparency
- Google Play 512 × 512 icon
- Google Play 1024 × 500 feature graphic
- Phone screenshots for supported screen sizes
- Optional tablet screenshots
- Final support URL and privacy-policy URL

These assets must accurately show the released application. Generated marketing images must not depict functionality absent from version 1.0.0.

## Manual release sequence

1. Confirm product name and bundle identifiers are available in both developer portals.
2. Publish the privacy policy at a stable HTTPS URL.
3. Create the applications in Play Console and App Store Connect.
4. Configure signing credentials outside the repository.
5. Run `Store Release Readiness` in GitHub Actions.
6. Download and install the Android release APK on at least one physical device.
7. Upload the signed AAB to Google Play internal testing.
8. Upload the signed iOS archive to TestFlight.
9. Complete Play Data Safety and Apple App Privacy forms using this document.
10. Test the Play internal-test build and TestFlight build on physical devices.
11. Add approved screenshots, descriptions, support URL, and privacy URL.
12. Submit to review only after both physical-device smoke tests pass.

## Release blockers

A production submission must not proceed when any of these remain unresolved:

- Missing Apple or Google developer account access
- Missing production signing credentials
- Default Flutter launcher icon
- Missing final screenshots
- Privacy policy not hosted at an HTTPS URL
- Bundle ID or application ID conflict
- Store metadata does not match actual app behavior
- A CI job is not green
- Physical-device smoke test has not been completed
