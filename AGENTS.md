# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

ForeignScan (智能防异物检测系统) is a Flutter app for industrial foreign-object detection. The Android tablet/phone captures images at predefined "scenes", uploads them via WiFi to a Go (Gin) backend server, which runs YOLO-based detection and returns results. The app also performs on-device ORB feature matching (via C++ OpenCV through Dart FFI) to verify the camera is pointed at the correct scene before uploading.

## Build & Run Commands

```bash
flutter pub get                    # Install dependencies
flutter run                        # Run on connected device/emulator
flutter build apk --release        # Build release APK
flutter analyze                    # Static analysis (always run before finishing work)
```

### OpenCV SDK Setup (Android only, required for build)

The native ORB matcher requires OpenCV Android SDK. Either:
- Place it at `android/third_party/OpenCV-android-sdk/sdk`, OR
- Set `opencv.sdk=/absolute/path/to/OpenCV-android-sdk/sdk` in `android/local.properties`

Build will fail with a GradleException if the SDK is not found.

### Release Signing

Configure `android/key.properties` (see `android/key.properties.example`). Without it, release builds fall back to debug signing.

## Architecture

### Layer Structure

```
lib/
├── config/          # AppConfig (camera/network/image/detection constants), AppConstants (routes, keys, UI tokens)
├── core/
│   ├── providers/   # Riverpod providers — the "ViewModel" layer (HomeViewModel, camera, detection, app-level)
│   ├── routes/      # AppRouter — named-route onGenerateRoute with static navigation helpers
│   ├── services/    # Business logic — WiFiCommunicationService, DetectionService, SceneService,
│   │                #   RecordService, OrbFfiService, LocalCacheService, ServerConfigService, etc.
│   ├── theme/       # AppTheme — light/dark themes, semantic colors, design tokens
│   └── widgets/     # Shared base widgets (LoadingWidget, ErrorWidgetCustom, AppBarActions)
├── models/          # Data classes: SceneData, DetectionResult, InspectionRecord, StyleImage, VerificationRecord
├── screens/         # Page-level widgets, some with sub-directories for controllers and child widgets
│   ├── home/        # HomePage split into controllers/ and widgets/ (HomeMainLayout, ServerSetupDialog, etc.)
│   └── record_detail/  # RecordDetailPage with sectioned widget files
├── utils/           # CameraManager, ScreenUtils
└── widgets/         # Domain-specific reusable widgets (AppDrawer, SceneSelector, RecordsSection, etc.)
```

### Key Patterns

- **State management**: Flutter Riverpod (`StateNotifierProvider` for complex state like `HomeViewModel`, `FutureProvider` for async data, `Provider` for services). No code-generation for providers is currently used at runtime.
- **Data flow**: "Network first + local fallback" — services try the backend API first, fall back to `SharedPreferences` JSON cache when offline. See `DetectionService.getDetectionResultsHybrid()` and `SceneService.getScenes()`.
- **Routing**: Named routes defined in `AppConstants`, resolved in `AppRouter.onGenerateRoute`. Navigate via `AppRouter.navigateToXXX()` static helpers.
- **Native interop**: `OrbFfiService` loads `liborb_matcher.so` via `dart:ffi` to call OpenCV ORB/BFMatcher C++ code (`android/app/src/main/cpp/orb_matcher.cpp`). Android-only.
- **Server communication**: `WiFiCommunicationService` uses its own `Dio` instance with explicit `http://<ip>:<port>` URLs. The global `dioProvider` in `app_providers.dart` uses `NetworkConfig.apiBaseUrl` as base URL. Server address is user-configurable and persisted in `SharedPreferences`.

### Backend API

The backend is a separate Go/Gin server (not in this repo). Key endpoints used:
- `GET /ping` — connectivity test
- `GET /api/scenes`, `GET /api/scenes/{id}` — scene list and detail
- `POST /api/upload-image` — image upload (multipart, fields: `file`, `sceneId`)
- `GET /api/detections`, `GET /api/images/{imageId}/detections` — detection results
- `GET /api/style-images/scene/{sceneId}` — style/reference images per scene
- `POST /api/inspection-records`, `POST /api/inspection-records/batch` — record sync

## Conventions

- **Language**: UI strings and business-logic comments are in Chinese (中文). Keep this convention.
- **Visual tokens**: Always use `AppTheme` and `AppConstants` for colors, spacing, border radius, and elevation. Do not introduce new hard-coded values.
- **Error/loading states**: Use `LoadingWidget` and `ErrorWidgetCustom` for consistent async state rendering.
- **SnackBar feedback**: Use semantic colors from `AppTheme` (`successColor`, `warningColor`, `errorColor`).
- **Tablet awareness**: The app targets both phone and tablet. Use responsive layouts (split-pane on wide screens). See the `foreignscan-pad-development` skill for detailed tablet layout guidance.
- **Service vs UI separation**: Network calls and persistence logic belong in `core/services/`. Providers compose services. UI widgets read state from providers and dispatch actions — no direct HTTP calls in widget trees.
