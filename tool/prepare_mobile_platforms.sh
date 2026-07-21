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

podfile = Path('ios/Podfile')
if podfile.exists():
    text = podfile.read_text()
    if "platform :ios" in text:
        import re
        text = re.sub(r"#?\s*platform :ios,\s*'[^']+'", "platform :ios, '15.0'", text, count=1)
    else:
        text = "platform :ios, '15.0'\n\n" + text
    podfile.write_text(text)

project = Path('ios/Runner.xcodeproj/project.pbxproj')
if project.exists():
    text = project.read_text()
    import re
    text = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;', text)
    project.write_text(text)
PY

echo "Mobile platforms prepared with Decidoo permissions and iOS 15 deployment target."
