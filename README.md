# LizasCookies Flutter App

Native Android app for LizasCookies e-commerce built with Flutter 3.24+.

## Tech Stack

- **Framework**: Flutter 3.24+
- **Language**: Dart 3.4+
- **State Management**: Riverpod 2.5+ (with Generator)
- **Navigation**: GoRouter 14+
- **Networking**: Dio + Retrofit
- **Serialization**: Freezed + JSON Serializable
- **Local Storage**: Hive + Flutter Secure Storage
- **Push Notifications**: Firebase Messaging + Local Notifications
- **Architecture**: Clean Architecture + Feature-First

## Project Structure

```
lib/
├── core/                    # Shared kernel
│   ├── config/             # App config, flavors
│   ├── errors/             # Failure classes
│   ├── network/            # Dio client
│   ├── storage/            # Secure & Local storage
│   ├── theme/              # Theme, colors, typography
│   └── widgets/            # Shared UI components
├── data/                    # Data layer (implementation)
├── domain/                  # Business logic (pure Dart)
├── features/                # Feature modules
│   ├── auth/
│   ├── catalog/
│   ├── cart/
│   ├── checkout/
│   ├── orders/
│   ├── profile/
│   └── notifications/
├── presentation/            # UI layer
│   ├── providers/          # Global providers
│   └── routes/             # GoRouter config
└── main.dart               # Entry point
```

## Getting Started

### Prerequisites

- Flutter SDK 3.24+
- Dart SDK 3.4+
- Android Studio / VS Code
- Android SDK (API 35 for Android 15)

### Installation

```bash
# Navigate to project
cd lizas-cookies-flutter

# Install dependencies
flutter pub get

# Generate code (run after any model/provider changes)
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode for development
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Flavors

```bash
# Development
flutter run --flavor dev --dart-define=FLAVOR=dev

# Staging
flutter run --flavor staging --dart-define=FLAVOR=staging

# Production
flutter run --flavor prod --dart-define=FLAVOR=prod
```

### Build

```bash
# Debug APK
flutter build apk --flavor dev --dart-define=FLAVOR=dev

# Release AAB (Play Store)
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod \
  --obfuscate --split-debug-info=build/debug-info
```

## Code Generation

Run after modifying:
- Freezed models (`@freezed`)
- Riverpod providers (`@riverpod`)
- Retrofit APIs (`@RestApi`)
- Hive models (`@HiveType`)

```bash
# One-time build
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode (auto-regenerate on save)
flutter pub run build_runner watch --delete-conflicting-outputs
```

## Architecture Guidelines

### Feature Module Structure

```
features/{feature}/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── presentation/
│   ├── pages/
│   ├── widgets/
│   └── providers/
└── {feature}_feature.dart
```

### State Management (Riverpod)

- Use `@riverpod` for all providers
- Prefer `AsyncNotifierProvider` for async operations
- Use `NotifierProvider` for simple synchronous state
- Keep providers in `presentation/providers/`

### Error Handling

- Use `Either<Failure, T>` from `dartz` for repository returns
- Handle `DioException` in repository implementations
- Map to user-friendly messages via `Failure.userMessage`

### Navigation

- Use GoRouter declarative routes
- Define routes in `presentation/routes/app_router.dart`
- Use `context.push('/path')` for navigation
- Deep links handled automatically

## API Integration

Base URLs per flavor:
- **Dev**: `https://dev.lizascookies.id/api/v1`
- **Staging**: `https://staging.lizascookies.id/api/v1`
- **Prod**: `https://lizascookies.id/api/v1`

Endpoints used:
- Auth: `/v1/login`, `/v1/register`, `/v1/logout`, `/v1/user`
- Catalog: `/member/products`, `/member/categories`
- Cart: Local only (sync on checkout)
- Orders: `/member/orders`, `/member/orders/check-rates`
- Payment: `/payment/duitku/request`
- Addresses: `/member/addresses`

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html
```

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`):
1. Analyze (`dart analyze`)
2. Format check (`dart format --check`)
3. Test (`flutter test --coverage`)
4. Build APK/AAB per flavor
5. Deploy to Firebase App Distribution / Play Console

## Resources

- [Architecture Documentation](docs/ARCHITECTURE.md)
- [Development TODO](docs/TODO.md)
- [API Documentation](https://lizascookies.id/docs/api) (Scramble)

## License

Proprietary - LizasCookies © 2025