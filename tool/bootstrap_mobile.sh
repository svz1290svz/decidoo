#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or not available in PATH."
  exit 1
fi

flutter create \
  --platforms=android,ios \
  --org=com.decidoo \
  --project-name=decidoo \
  .

flutter pub get
flutter analyze
flutter test

echo "Android and iOS projects are ready."
echo "Run Android: flutter run -d android"
echo "Run iOS: flutter run -d ios"
