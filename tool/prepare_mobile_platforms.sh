#!/usr/bin/env bash
set -euo pipefail

flutter create --no-pub --platforms=android,ios --org com.decidoo .

python3 - <<'PY'
from pathlib import Path

manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    text = manifest.read_text()
    fine = '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />'
    coarse = '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />'
    if fine not in text:
        marker = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
        text = text.replace(marker, marker + '\n    ' + fine + '\n    ' + coarse)
        manifest.write_text(text)

plist = Path('ios/Runner/Info.plist')
if plist.exists():
    text = plist.read_text()
    key = '<key>NSLocationWhenInUseUsageDescription</key>'
    if key not in text:
        addition = '\t<key>NSLocationWhenInUseUsageDescription</key>\n\t<string>Yakındaki restoranları ve yemekleri önermek için konumunuz kullanılır.</string>\n'
        text = text.replace('</dict>', addition + '</dict>')
        plist.write_text(text)
PY

echo "Mobile platforms prepared with Decidoo location permissions."
