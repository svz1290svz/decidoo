# Decidoo

Decidoo is a global decision engine that removes the friction from choosing what to eat. It returns one explainable, personalized decision instead of an endless list.

## Current product

- Premium mobile-first Flutter experience
- Android and iOS project bootstrap
- Automatic device-language detection
- In-app language selector
- English, Turkish, German, French, Spanish and Arabic UI
- Automatic right-to-left layout for Arabic
- Goal, budget and meal-time personalization
- Explainable weighted recommendation scoring
- Recent-choice diversity to reduce repetition
- Favorites, discovery and decision history
- Global starter food catalog
- Deterministic unit tests for the decision engine
- Modular domain, data, localization, service and presentation layers

## Create Android and iOS projects

### Windows

```bat
git pull
tool\bootstrap_mobile.bat
```

### macOS or Linux

```bash
git pull
chmod +x tool/bootstrap_mobile.sh
./tool/bootstrap_mobile.sh
```

The bootstrap command creates the native `android/` and `ios/` folders with the application identifier `com.decidoo.decidoo`, installs packages, analyzes the code and runs tests.

## Run

```bash
flutter pub get
flutter test
flutter run
```

Android builds can be produced on Windows, macOS or Linux. iOS compilation and App Store signing require macOS with Xcode and an Apple Developer account.

## Release commands

```bash
flutter build appbundle --release
flutter build apk --release
flutter build ios --release
```

## Architecture

```text
lib/
  main.dart
  src/
    app.dart
    localization/app_localizations.dart
    data/food_catalog.dart
    domain/food.dart
    services/decision_engine.dart
tool/
  bootstrap_mobile.bat
  bootstrap_mobile.sh
```

The recommendation engine is independent from Flutter. It can later be moved behind an API or combined with a remote ML ranking service without rewriting the interface.

## Scale roadmap

### Phase 1 — Product validation

- Authentication and anonymous sessions
- Persistent locale, favorites and decision history
- Dietary restrictions and allergy controls
- Location permission and nearby restaurant inventory
- Analytics events, crash reporting and feature flags

### Phase 2 — Marketplace intelligence

- Restaurant and menu ingestion
- Distance, availability, delivery time and live price signals
- Sponsored recommendations with explicit labeling
- Restaurant dashboard and campaign attribution
- Translated food catalog and regional ranking models

### Phase 3 — Global platform

- API gateway, rate limiting and regional deployment
- Event pipeline and recommendation feedback loop
- Experimentation platform and model monitoring
- Privacy, consent, deletion and data portability workflows
- Abuse prevention, observability and disaster recovery

## Product principle

Decidoo should optimize for trusted decisions, not maximum scrolling. Recommendation quality, user control and transparent commercial placement are core requirements.
