# Z Mobile

Flutter client for **Z**, a mobile-first app that records speech, sends it to a backend for transcription and AI email generation, then lets the user review, save, and open the generated email in a mail application.

The visible product copy is mostly French (`Parlez. Z rédige.`), while several settings and history labels are currently in English.

## Main Features

- Onboarding flow with persisted completion state.
- Email/password registration, login, logout, email verification, token refresh, and profile update.
- Secure auth token storage using `flutter_secure_storage`.
- Voice recording with microphone permission handling and temporary `.m4a` files.
- Speech transcription through a backend endpoint.
- AI email generation from a transcript, template, tone, input language, and output language.
- Editable email preview with recipient, subject, body, tone regeneration, draft saving, and mail-app handoff.
- Draft history with local fallback, search, status filters, duplicate, restore, delete, and offline indicator.
- User preferences for theme mode, accent color, transcription language, generated email language, and preferred mail app.
- Mail composer integration for Gmail, Outlook, system mailto handlers, and copy-only fallback.
- Cross-platform Flutter project structure for Android, iOS, web, macOS, Linux, and Windows.

## Tech Stack

- **Framework:** Flutter
- **Language:** Dart
- **State management:** Inherited widget plus `ChangeNotifier`
- **HTTP client:** Dart `HttpClient`
- **Local preferences:** `shared_preferences`
- **Secure storage:** `flutter_secure_storage`
- **Audio recording:** `record`
- **Temporary file paths:** `path_provider`
- **Mail app launching:** `url_launcher`
- **Linting:** `flutter_lints`
- **Launcher icon generation:** `flutter_launcher_icons`

## Project Architecture

This repository contains a Flutter frontend only. No backend source code, database schema, migrations, Docker setup, or CI/CD configuration is present in this project.

The app starts in `lib/main.dart`, loads runtime configuration through `AppConfig`, creates an app-wide `AppSession`, and exposes `ZApi` plus session state through `ZScope`.

High-level runtime flow:

1. `main()` loads `.env` and Dart defines through `AppConfig.load()`.
2. `ZApp` creates `ZApi` and `AppSession`.
3. `AppSession.initialize()` loads preferences, restores tokens, refreshes the user session, and loads drafts.
4. `MaterialApp.onGenerateRoute` guards protected routes and renders screens.
5. Screens call `ZApi` for authentication, profile, transcription, generation, and draft operations.
6. Session state is persisted through secure storage and shared preferences.

## Folder Structure

```text
.
├── android/                  # Android platform project and manifests
├── assets/
│   ├── icons/                # Launcher icon source assets
│   └── images/               # App logo assets
├── ios/                      # iOS platform project and Info.plist permissions
├── lib/
│   ├── core/
│   │   ├── config/           # Runtime configuration loader
│   │   └── services/         # Mail launcher service
│   └── main.dart             # App entry point, routes, API client, models, screens, widgets
├── linux/                    # Linux desktop platform project
├── macos/                    # macOS desktop platform project
├── test/                     # Flutter tests
├── web/                      # Web entry point, manifest, and icons
├── windows/                  # Windows desktop platform project
├── analysis_options.yaml     # Dart analyzer and lint configuration
├── pubspec.yaml              # Flutter dependencies, assets, and launcher icon config
└── pubspec.lock              # Locked dependency versions
```

## Prerequisites

- Flutter SDK with a Dart SDK compatible with `^3.12.1`.
- Xcode and CocoaPods for iOS/macOS builds.
- Android Studio, Android SDK, and an emulator or physical device for Android builds.
- A running backend that implements the `/api/v1` endpoints used by the app.
- Microphone access on the target device or simulator.

Check your Flutter installation:

```bash
flutter doctor
```

## Installation After Cloning

### macOS / Linux

```bash
git clone <repository-url>
cd z-flutter-UI
flutter pub get
cp .env.example .env
```

`cp .env.example .env` will only work after `.env.example` is added to the repository. At the moment, this project contains a `.env` file but no `.env.example`.

### Windows PowerShell

```powershell
git clone <repository-url>
cd z-flutter-UI
flutter pub get
Copy-Item .env.example .env
```

`Copy-Item .env.example .env` will only work after `.env.example` is added to the repository.

## Environment Variables Setup

The app loads configuration from:

1. Dart defines passed to `flutter run` or `flutter build`.
2. The bundled `.env` asset.
3. Development fallbacks.

Supported variables:

| Variable | Required | Description |
| --- | --- | --- |
| `APP_ENV` | No | App environment. Supported values include `development`, `staging`, and `production`. Defaults to `development`. |
| `ENVIRONMENT` | No | Alternative name for `APP_ENV`. |
| `API_BASE_URL` | Required outside development fallback | Backend origin used to build `${API_BASE_URL}/api/v1`. Example: `http://localhost:3000`. |
| `DEVELOPMENT_API_BASE_URL` | No | Environment-specific backend origin for development. |
| `STAGING_API_BASE_URL` | No | Environment-specific backend origin for staging. |
| `PRODUCTION_API_BASE_URL` | No | Environment-specific backend origin for production. |
| `API_PORT` | No | Development fallback port. Defaults to `3000`. |
| `API_LAN_IP` | Required for iOS physical devices when `API_BASE_URL` is omitted | LAN IP used to reach a local backend from a physical iOS device. |

Example `.env`:

```env
APP_ENV=development
API_BASE_URL=http://localhost:3000
```

Do not include `/api` or `/api/v1` in `API_BASE_URL` unless the backend is intentionally mounted that way. The app appends `/api/v1` internally.

Development fallback behavior when `API_BASE_URL` is omitted:

- Android emulator: `http://10.0.2.2:<API_PORT>`
- iOS simulator: `http://localhost:<API_PORT>`
- Other local targets: `http://localhost:<API_PORT>`
- iOS physical device: requires `API_LAN_IP`

You can also pass values at runtime:

```bash
flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://localhost:3000
```

## Database Setup

No database code, schema, migration files, or seed scripts exist in this repository.

The Flutter app expects a separate backend service to handle authentication, transcription, AI generation, user profiles, and drafts.

## Running Locally

Install dependencies first:

```bash
flutter pub get
```

Run on the default available device:

```bash
flutter run
```

Run on iOS simulator with a local backend:

```bash
flutter run -d "iPhone 17 Pro" --dart-define=API_BASE_URL=http://localhost:3000
```

Run on Android emulator with a local backend:

```bash
flutter run -d <ANDROID_EMULATOR_ID> --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Run on a physical iPhone against a backend running on your Mac:

```bash
flutter run -d <IPHONE_DEVICE_ID> --dart-define=API_BASE_URL=http://<MAC_LOCAL_IP>:3000
```

Before testing on a physical device, verify that the device can reach the backend from its browser:

```text
http://<MAC_LOCAL_IP>:3000/api/v1/health
```

## Available Commands

```bash
flutter pub get
```

Install dependencies.

```bash
flutter analyze
```

Run static analysis using `analysis_options.yaml`.

```bash
flutter test
```

Run the Flutter test suite.

```bash
flutter run
```

Start the app on a connected device, emulator, simulator, browser, or desktop target.

```bash
flutter build apk
flutter build appbundle
flutter build ios
flutter build web
flutter build macos
flutter build linux
flutter build windows
```

Build release artifacts for supported Flutter targets.

```bash
dart run flutter_launcher_icons
```

Regenerate launcher icons from `assets/icons/z_launcher.png`.

## API Documentation

This repository does not contain backend route implementations. The API below is the contract used by the Flutter client in `ZApi`.

All JSON endpoints are called under:

```text
{API_BASE_URL}/api/v1
```

Authenticated requests send:

```text
Authorization: Bearer <accessToken>
```

Draft requests also send:

```text
X-Device-Id: <deviceId>
```

### Authentication

| Method | Path | Request body | Client expectation |
| --- | --- | --- | --- |
| `POST` | `/auth/register` | `email`, `name`, `password` | Returns `requiresEmailVerification` and `email`. |
| `POST` | `/auth/login` | `email`, `password` | Returns `user`, `accessToken`, and `refreshToken`. |
| `POST` | `/auth/verify-email` | `email`, `code` | Returns `user`, `accessToken`, and `refreshToken`. |
| `POST` | `/auth/resend-verification-code` | `email` | Sends a new verification code. |
| `POST` | `/auth/refresh` | `refreshToken` | Returns refreshed auth result. |
| `POST` | `/auth/logout` | `{}` | Invalidates the current session. |

If login returns `401`, the app displays `Email ou mot de passe incorrect.`. If the backend returns code `EMAIL_NOT_VERIFIED`, the app redirects to email verification.

### Users

| Method | Path | Request body | Client expectation |
| --- | --- | --- | --- |
| `GET` | `/users/me` | None | Returns `id`, `email`, and `name`. |
| `PATCH` | `/users/me` | `name` | Returns updated `id`, `email`, and `name`. |

### Speech

| Method | Path | Request | Client expectation |
| --- | --- | --- | --- |
| `POST` | `/speech/transcribe` | Multipart form with `language` and `audio` fields | Returns `transcript`, `language`, `confidence`, and `duration`. |

The audio upload uses an `.m4a` filename and a MIME type inferred from the local recording path. The app sends `language=auto` or one of the configured language codes.

### AI Email Generation

| Method | Path | Request body | Client expectation |
| --- | --- | --- | --- |
| `POST` | `/ai/generate-email` | `transcript`, optional `tone`, `customTone`, `template`, `language`, `outputLanguage` | Returns `language`, `tone`, `intent` or `detectedIntent`, `subject`, `body`, and optional suggested recipient fields. |

Supported tone values in the client:

- `professional`
- `administrative`
- `student`
- `friendly`
- `formal`
- `business`
- `custom`

### Drafts

| Method | Path | Request body | Client expectation |
| --- | --- | --- | --- |
| `GET` | `/drafts` | None | Returns a list in `data`, `items`, or `drafts`. |
| `POST` | `/drafts` | `recipient`, `subject`, `body`, `tone`, `transcript`, `templateKey` | Returns the saved draft. |
| `POST` | `/drafts/claim-device-drafts` | `deviceId` | Associates local device drafts with the authenticated account. |
| `PATCH` | `/drafts/{draftId}/status` | `status` | Updates draft status. |
| `DELETE` | `/drafts/{draftId}` | None | Deletes a draft. |
| `POST` | `/drafts/{draftId}/duplicate` | `{}` | Returns duplicated draft. |

Supported draft statuses in the client:

- `draft`
- `scheduled`
- `opened_in_mail_app`
- `deleted`

## Frontend Routes and Screens

| Route | Screen | Protected | Purpose |
| --- | --- | --- | --- |
| `/splash` | `SplashScreen` | No | Loads session state and redirects. |
| `/onboarding` | `OnboardingScreen` | No | First-run introduction. |
| `/login` | `LoginScreen` | No | Email/password login. |
| `/register` | `RegisterScreen` | No | Account creation. |
| `/verify-email` | `VerifyEmailScreen` | No | Six-digit email verification and resend timer. |
| `/home` | `HomeScreen` | Yes | Main dashboard and recent drafts. |
| `/voice-record` | `VoiceRecordScreen` | Yes | Record audio, transcribe speech, and generate email. |
| `/email-preview` | `EmailPreviewScreen` | Yes | Edit generated email, regenerate tone, save draft, and open mail app. |
| `/history` | `HistoryScreen` | Yes | Search, filter, open, duplicate, delete, and restore drafts. |
| `/settings` | `SettingsScreen` | Yes | Appearance, language, mail app, and account shortcuts. |
| `/profile` | `ProfileScreen` | Yes | View/update profile and logout. |

Protected routes redirect unauthenticated users to `/login`.

## Authentication Flow

1. The user registers with name, email, password, and password confirmation.
2. Registration redirects to `/verify-email`.
3. The user enters a six-digit verification code.
4. Verification returns an access token, refresh token, and user profile.
5. Tokens and user profile are stored in secure storage.
6. On app startup, the app attempts to fetch `/users/me` using the access token.
7. If that fails and a refresh token exists, the app calls `/auth/refresh`.
8. If refresh fails, auth state is cleared and the user is sent back to login.
9. Authenticated users can optionally claim drafts created on the current device.
10. Logout calls `/auth/logout`, clears secure storage, and returns to login.

## Languages and Preferences

Speech and generated email language choices are:

- `auto` - Auto Detect
- `fr` - Français
- `en` - English
- `ar` - العربية
- `de` - Deutsch
- `es` - Español
- `it` - Italiano
- `pt` - Português
- `nl` - Nederlands
- `tr` - Türkçe

Persisted local preference keys include:

- `z.deviceId`
- `z.onboardingComplete`
- `z.themeMode`
- `z.accentColor`
- `z.transcriptionLanguage`
- `z.emailOutputLanguage`
- `z.preferredMailApp`
- `z.localHistory`

Secure storage keys include:

- `z.auth.accessToken`
- `z.auth.refreshToken`
- `z.auth.user`

## Platform Permissions and Configuration

Android declares:

- `android.permission.RECORD_AUDIO`
- `android.permission.INTERNET`
- Mailto query support for external mail apps.

iOS declares:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- URL query schemes for `mailto`, `googlegmail`, and `ms-outlook`.

The web manifest defines the app name `Z`, short name `Z`, portrait orientation, theme color `#2563EB`, and description `Parlez. Z rédige.`.

## Deployment Instructions

No deployment pipeline is included in this repository.

Build examples:

```bash
flutter build apk --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://your-api.example.com
flutter build appbundle --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://your-api.example.com
flutter build ios --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://your-api.example.com
flutter build web --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://your-api.example.com
```

For iOS distribution, configure signing, bundle identifier, capabilities, and release settings in Xcode.

For Android distribution, configure signing in the Android project before publishing an APK or App Bundle.

For web deployment, serve the generated `build/web` directory from a static host.

## Testing Instructions

Run all tests:

```bash
flutter test
```

Run static analysis:

```bash
flutter analyze
```

Current tests:

- `test/widget_test.dart`: smoke test.
- `test/mail_launcher_service_test.dart`: verifies safe percent encoding for mailto, Gmail, and Outlook composer URLs, including spaces, punctuation, French, Arabic, and long bodies.

## Troubleshooting

### Backend cannot be reached

The app shows:

```text
Impossible de joindre le serveur. Vérifiez l’adresse API et le backend.
```

Check that:

- The backend is running.
- `API_BASE_URL` points to the backend origin.
- The backend exposes `/api/v1`.
- A physical device can reach the backend over the same network.
- The host firewall allows inbound connections.

### Android emulator cannot reach `localhost`

Use the Android host alias:

```bash
flutter run -d <ANDROID_EMULATOR_ID> --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

### iOS physical device cannot reach `localhost`

Use the Mac LAN IP:

```bash
flutter run -d <IPHONE_DEVICE_ID> --dart-define=API_BASE_URL=http://<MAC_LOCAL_IP>:3000
```

### Incorrect API path

If `API_BASE_URL` already contains `/api`, the app may call an unexpected URL such as `/api/api/v1/...`. Use the backend origin, for example:

```env
API_BASE_URL=http://localhost:3000
```

### Microphone recording fails

Check microphone permissions on the device or simulator. Android and iOS permission declarations already exist in the platform projects.

### Mail app does not open

The app falls back to a copy dialog if no compatible mail app is available. Check the preferred mail app in Settings and confirm that Gmail, Outlook, or a default mail handler is installed.

### Email verification redirects after login

If the backend returns `EMAIL_NOT_VERIFIED`, the app redirects to `/verify-email` and uses the email returned by the API when available.

## Contribution Guide

1. Create a feature branch.
2. Keep changes focused and consistent with the existing Flutter structure.
3. Run formatting, analysis, and tests before opening a pull request.
4. Do not commit secrets, real API keys, signing files, or local environment files.
5. Update this README when routes, environment variables, API expectations, or setup steps change.

Recommended checks:

```bash
dart format .
flutter analyze
flutter test
```

## Missing Information / To Complete

- Add `.env.example`; `.gitignore` expects it, but it is not present.
- Add backend repository link or setup instructions.
- Add backend API specification if available.
- Add database setup, migrations, and seed instructions if managed elsewhere.
- Add production deployment process for each target platform.
- Add app signing instructions for Android and iOS.
- Add CI/CD documentation if a pipeline is created.
- Add license text or identify the intended license.

## License

No license file is present in this repository. Add a license before distributing or accepting external contributions.
