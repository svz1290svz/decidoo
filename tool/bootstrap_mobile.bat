@echo off
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter is not installed or not available in PATH.
  exit /b 1
)

flutter create --platforms=android,ios --org=com.decidoo --project-name=decidoo .
if errorlevel 1 exit /b 1

flutter pub get
if errorlevel 1 exit /b 1

flutter analyze
if errorlevel 1 exit /b 1

flutter test
if errorlevel 1 exit /b 1

echo Android and iOS projects are ready.
echo Android: flutter run -d android
echo iOS builds require macOS and Xcode.
