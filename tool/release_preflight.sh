#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "::error::$1"
  exit 1
}

[[ -f pubspec.yaml ]] || fail "pubspec.yaml is missing"
[[ -f docs/privacy-policy.md ]] || fail "Privacy policy is missing"
[[ -f store/google-play/en-US/full-description.txt ]] || fail "Google Play metadata is missing"
[[ -f store/app-store/en-US/description.txt ]] || fail "App Store metadata is missing"

grep -Eq '^version: [0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$' pubspec.yaml || fail "Version must use semantic format, for example 1.0.0+2"

if grep -RInE 'TODO|FIXME|CHANGE_ME|example\.com|your-company|YOUR_' lib test store docs --exclude='release-readiness.md'; then
  fail "Release-blocking placeholder or unfinished marker found"
fi

if grep -RInE '(api[_-]?key|secret|password)[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']+' lib --include='*.dart'; then
  fail "Possible hard-coded secret found in Dart sources"
fi

echo "Release preflight passed."
