# Repository Summary

- Primary language: Dart (Flutter)
- Platforms: Android, iOS, Web, Windows, Linux, macOS
- Key directories:
  - `lib/`: main Flutter application code (UI screens, services, widgets, utilities)
  - `android/`, `ios/`, `macos/`, `windows/`, `linux/`: platform-specific Flutter targets
  - `web/`: web build resources
  - `test/`: automated tests covering admin functionality, driver registration, and Firestore integration
- Notable files:
  - `lib/admin.dart`: Admin dashboard interface for managing drivers and system stats
  - `lib/driver_dashboard.dart`: Driver-facing dashboard and ride management
  - `lib/services/firestore_service.dart`: Firestore data access layer for drivers, rides, and police clearance records

## Configuration
- `pubspec.yaml`: Flutter dependencies and project metadata
- `analysis_options.yaml`: Lints and static analysis rules

## Build/Setup Notes
- Firebase configuration files present under `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
- `FIREBASE_SETUP.md` and related documentation provide environment setup and troubleshooting steps