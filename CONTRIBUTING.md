# Contributing to Decidoo

## Development setup

```bash
flutter create --platforms=android,ios --org com.decidoo .
flutter pub get
flutter analyze
flutter test
flutter run
```

## Branches and commits

- Create focused branches from `main`.
- Keep commits small and descriptive.
- Never commit secrets, generated credentials or signing files.
- Add or update tests for recommendation logic.
- Add localization keys for every user-visible string.

## Pull requests

A pull request must explain the user problem, implementation, validation and privacy impact. UI changes should include screenshots. CI must pass before merge.

## Product rules

- Decidoo returns a trusted decision, not an endless feed.
- Sponsored results must be explicitly labeled.
- Allergy and dietary restrictions must never be treated as soft preferences.
- Recommendation logic must remain explainable and testable.
- New markets require reviewed translations and regional food data.
