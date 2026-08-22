# LizasCookies Flutter - Development TODO

## Project Status: **Phase 1-4 Partial** (Week 1-3)

---

## Phase 1: Project Setup & Foundation ✅

### Completed
- [x] Create project folder structure
- [x] Create `pubspec.yaml` with all dependencies
- [x] Create `docs/ARCHITECTURE.md`
- [x] Create `docs/TODO.md`
- [x] Set up flavors (dev/staging/prod)
- [x] Configure `main.dart` entry point with Riverpod
- [x] Set up Riverpod providers (manual, no codegen)
- [x] Configure GoRouter with routes + bottom nav
- [x] Set up Dio client + auth interceptor
- [x] Configure Secure Storage + Hive local storage
- [x] Set up theme system (light/dark) with Poppins via google_fonts
- [x] Configure build runner & code generation → **Removed (incompatible with Dart 3.13)**
- [x] Run `flutter pub get` and verify build

### Pending
- [ ] Set up Firebase project config (google-services.json)
- [ ] Configure flutter_launcher_icons
- [ ] Configure flutter_native_splash

---

## Phase 2: Authentication Feature ✅

### Domain Layer
- [x] `AuthEntity` (User, Tokens, AuthState - sealed classes)
- [x] `AuthRepository` interface
- [x] `LoginUseCase`, `RegisterUseCase`, `LogoutUseCase`, `RefreshTokenUseCase`, `GetProfileUseCase`

### Data Layer
- [x] `AuthRemoteDataSource` (manual Dio)
- [x] `AuthLocalDataSource` (Secure Storage)
- [x] `AuthRepositoryImpl` (full error handling)

### Presentation Layer
- [x] `AuthNotifier` (Riverpod StateNotifier)
- [x] Login Page UI (placeholder)
- [x] Register Page (placeholder)
- [x] Forgot Password Page (placeholder)

### Resolved Issues
- ✅ Removed freezed/riverpod_generator (incompatible with Dart 3.13 SDK)
- ✅ All entities/models use manual Dart classes
- ✅ All providers use manual Riverpod providers

---

## Phase 3: Catalog Feature ✅ (Skeleton)

### Domain Layer
- [x] `ProductEntity`, `CategoryEntity`, `BannerEntity`
- [x] `CatalogRepository` interface
- [x] `GetProductsUseCase`, `GetProductDetailUseCase`, `GetCategoriesUseCase`, `SearchProductsUseCase`

### Data Layer
- [x] `CatalogRemoteDataSource` (manual Dio)
- [x] `CatalogRepositoryImpl` (error handling with Dartz Either)

### Presentation Layer
- [x] `ProductsNotifier`, `ProductDetailNotifier`, `CategoriesNotifier`, `SearchNotifier`
- [x] **Home Page** (search bar, categories horizontal list, product grid)
- [x] **Product Detail Page** (image carousel, price, stock, description, add-to-cart button)
- [x] **Category Page** (product grid filtered by category)
- [x] **Search Page** (live search with results list)
- [x] Shimmer loading placeholders

---

## Phase 4: Cart Feature ✅ (Skeleton)

### Domain Layer
- [x] `CartItemEntity`, `CartEntity` (with computed totalItems, subtotal)
- [x] Manual copyWith, toJson, fromJson

### Data Layer
- [x] `CartLocalDataSource` (Secure Storage persistence)

### Presentation Layer
- [x] `CartNotifier` (add, update qty, remove, clear)
- [x] `cartProvider`, `cartItemCountProvider`, `cartTotalProvider`
- [x] **Cart Page** (item list, quantity controls, swipe-to-delete, subtotal, checkout button)
- [x] Clear cart confirmation dialog

### Offline Support
- [x] Full offline cart (persisted locally via Secure Storage)

---

## Phase 5: Checkout & Orders (Week 3-4) ⏳

### Domain Layer
- [ ] `OrderEntity`, `AddressEntity`, `ShippingRateEntity`
- [ ] `CheckoutRepository`, `OrderRepository` interfaces
- [ ] `CreateOrderUseCase`, `CheckShippingRatesUseCase`, `GetOrdersUseCase`

### Data Layer
- [ ] `CheckoutRemoteDataSource`
- [ ] `OrderRemoteDataSource`
- [ ] `AddressLocalDataSource` (Hive)

### Presentation Layer
- [ ] `CheckoutNotifier`, `OrdersNotifier`
- [ ] Checkout Page (address → shipping → payment)
- [ ] Address Selection/Management
- [ ] Shipping Rate Selection (Biteship)
- [ ] Payment Page (Duitku integration)
- [ ] Order Success Page
- [ ] Orders List Page
- [ ] Order Detail Page

---

## Phase 6: Profile & Settings (Week 4) ⏳

### Domain Layer
- [ ] `ProfileEntity`
- [ ] `GetProfileUseCase`, `UpdateProfileUseCase`, `ChangePasswordUseCase`

### Presentation Layer
- [ ] Profile Page
- [ ] Edit Profile Page
- [ ] Change Password Page
- [ ] Address Management (CRUD)
- [ ] Settings Page
- [ ] Logout confirmation

---

## Phase 7: Push Notifications (Week 4-5) ⏳

- [ ] Firebase Console project setup
- [ ] `google-services.json` for each flavor
- [ ] FCM token registration
- [ ] Background message handler
- [ ] Foreground notification display
- [ ] Deep link handling

---

## Phase 8: Polish & Release (Week 5) ⏳

- [ ] Offline sync (WorkManager)
- [ ] Error handling & retry
- [ ] Unit tests
- [ ] Widget tests
- [ ] Performance optimization
- [ ] Signing config & release builds

---

## Technical Decisions

### Removed Packages (Dart 3.13 incompatible):
- ❌ `freezed` / `freezed_annotation` → Manual sealed classes
- ❌ `riverpod_generator` / `riverpod_annotation` → Manual Riverpod providers
- ❌ `build_runner` → Not needed
- ❌ `json_serializable` → Manual `fromJson`/`toJson`
- ❌ `retrofit` → Manual Dio calls

### Current Stack:
- **State**: Riverpod (manual providers)
- **Routing**: GoRouter
- **Network**: Dio + interceptors
- **Storage**: SecureStorage + Hive
- **Theme**: Material 3 + Google Fonts (Poppins)
- **Architecture**: Clean Architecture (feature-first)

---

*Last Updated: 2026-08-22*
*Current Phase: 1-4 (Setup, Auth, Catalog, Cart)*
*Next: Phase 5 - Checkout & Orders*
