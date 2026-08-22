# LizasCookies Flutter App - Architecture Documentation

## Overview
Native Android app for LizasCookies e-commerce built with Flutter 3.24+, targeting Android 15 (API 35) with HyperOS 2 Xiaomi compatibility.

## Tech Stack

| Layer | Technology | Version |
|-------|------------|---------|
| Framework | Flutter | 3.24+ |
| Language | Dart | 3.4+ |
| State Management | Riverpod + Generator | 2.5+ |
| Navigation | GoRouter | 14.2+ |
| Networking | Dio + Retrofit | 5.5+ / 4.2+ |
| Serialization | Freezed + JSON Serializable | 2.5+ / 6.8+ |
| Local DB | Hive | 2.2+ |
| Secure Storage | Flutter Secure Storage | 9.2+ |
| Push Notifications | Firebase Messaging + Local Notifications | 15.1+ / 17.2+ |
| Code Gen | Build Runner | 2.4+ |

## Architecture Pattern

```
Clean Architecture + Feature-First Structure
```

### Layer Responsibilities

```
lib/
├── core/                    # Shared kernel (independent of features)
│   ├── config/             # App config, flavors, constants
│   ├── constants/          # App-wide constants
│   ├── errors/             # Failure classes, exceptions
│   ├── extensions/         # Dart extensions
│   ├── theme/              # Theme, colors, typography
│   ├── utils/              # Helpers, formatters
│   └── widgets/            # Shared UI components
│
├── data/                    # Data layer (implementation)
│   ├── datasources/        # Remote (API) & Local (Cache/DB)
│   ├── models/             # DTOs (Freezed + JSON)
│   ├── repositories/       # Repository implementations
│   └── services/           # Platform services (notifications, etc.)
│
├── domain/                  # Business logic (pure Dart, no Flutter)
│   ├── entities/           # Domain entities (Freezed)
│   ├── repositories/       # Repository contracts (abstract)
│   ├── usecases/           # Business use cases
│   └── value_objects/      # Value objects
│
├── presentation/            # UI layer (Flutter dependent)
│   ├── providers/          # Riverpod providers (global)
│   ├── routes/             # GoRouter configuration
│   ├── theme/              # Theme provider
│   └── widgets/            # Shared presentation widgets
│
├── features/                # Feature modules (self-contained)
│   ├── auth/
│   ├── catalog/
│   ├── cart/
│   ├── checkout/
│   ├── orders/
│   ├── profile/
│   ├── notifications/
│   └── settings/
│
└── main.dart               # App entry point
```

## Feature Module Structure

Each feature follows:
```
features/{feature_name}/
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
└── {feature_name}_feature.dart  # Barrel export
```

## State Management (Riverpod)

### Provider Types Used:
- `Provider` - Simple dependencies (services, config)
- `StateNotifierProvider` - Complex state with logic
- `AsyncNotifierProvider` - Async operations (API calls)
- `NotifierProvider` - Synchronous state (new Riverpod 2.4+)
- `StreamProvider` - Real-time data (Firebase, WebSocket)
- `FutureProvider` - One-time async operations

### Code Generation:
```bash
# Generate providers
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode
flutter pub run build_runner watch --delete-conflicting-outputs
```

## Navigation (GoRouter)

- Declarative routing
- Deep linking support
- Redirect guards (auth, onboarding)
- Nested navigation per feature

## Networking

### API Client (Retrofit + Dio)
- Base URL per flavor (dev/staging/prod)
- Interceptors: Auth token, Logging, Error handling
- Automatic retry with exponential backoff
- Offline-first with cache-first strategy

### Endpoints Structure:
```
/api/public/*           # Public (no auth)
/api/member/*           # Authenticated user
/api/superadmin/*       # Admin only
/api/v1/*               # Versioned API
```

## Offline Strategy

1. **Cache-First**: Read from Hive, sync in background
2. **Optimistic Updates**: UI updates immediately, sync later
3. **Conflict Resolution**: Server wins, local changes queued
4. **Background Sync**: WorkManager / Flutter Background

## Push Notifications

- **Firebase Cloud Messaging** (FCM) for remote push
- **flutter_local_notifications** for local display
- **Deep linking** to specific screens
- **Topics**: `promo`, `order_updates`, `tenant_{id}`

## Flavors / Build Variants

| Flavor | Application ID | Base URL | Icon |
|--------|---------------|----------|------|
| dev | com.lizascookies.dev | https://dev-api.lizascookies.com | Dev badge |
| staging | com.lizascookies.staging | https://staging-api.lizascookies.com | Staging badge |
| prod | com.lizascookies | https://api.lizascookies.com | Clean |

## Dependency Injection

Using Riverpod providers as DI container:
- Services registered in `core/config/providers.dart`
- Repositories provided via `Provider` / `StateNotifierProvider`
- Use cases injected into Notifiers

## Testing Strategy

| Type | Tool | Coverage Target |
|------|------|-----------------|
| Unit | flutter_test + mocktail | 80%+ domain layer |
| Widget | flutter_test | Key user flows |
| Integration | integration_test | Critical paths |
| Golden | golden_toolkit | UI regression |

## CI/CD Pipeline

```yaml
# .github/workflows/ci.yml
1. Analyze (dart analyze)
2. Format check (dart format --check)
3. Test (flutter test --coverage)
4. Build (flutter build apk/appbundle --flavor=prod)
5. Deploy (Firebase App Distribution / Play Console)
```

## Performance Budgets

- App size: < 50MB (APK), < 100MB (AAB)
- Startup time: < 2s (cold), < 500ms (warm)
- Frame rate: 60fps (120fps on supported devices)
- Memory: < 150MB typical

## Security

- **Token Storage**: Flutter Secure Storage (Keychain/Keystore)
- **Certificate Pinning**: Dio Certificate Pinning
- **Obfuscation**: `--obfuscate --split-debug-info`
- **Minify**: R8/ProGuard enabled
- **Network Security Config**: Cleartext traffic blocked

## Accessibility

- Semantic labels on all interactive elements
- Sufficient contrast ratios (WCAG AA)
- Dynamic font size support
- TalkBack / VoiceOver tested

## Internationalization (i18n)

- ARB files for translations
- `intl` package for formatting
- RTL support ready
- Languages: Indonesian (primary), English

---

*Last updated: 2025-08-21*
*Version: 1.0.0*