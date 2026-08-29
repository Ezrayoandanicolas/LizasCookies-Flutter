// Core configuration for LizasCookies Flutter App
// This file defines app-wide constants, flavors, and environment config

enum AppFlavor {
  dev,
  staging,
  prod,
}

class AppConfig {
  final AppFlavor flavor;
  final String appName;
  final String baseUrl;
  final String apiVersion;
  final bool enableLogging;
  final bool enableCrashlytics;
  final String firebaseProjectId;

  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.baseUrl,
    required this.apiVersion,
    required this.enableLogging,
    required this.enableCrashlytics,
    required this.firebaseProjectId,
  });

  String get apiBaseUrl => '$baseUrl/api';

  static late final AppConfig _instance;

  static AppConfig get instance => _instance;

  static void initialize(AppFlavor flavor) {
    switch (flavor) {
      case AppFlavor.dev:
        _instance = const AppConfig(
          flavor: AppFlavor.dev,
          appName: 'LizasCookies Dev',
          baseUrl: 'https://dev.lizascookies.id',
          apiVersion: 'v1',
          enableLogging: true,
          enableCrashlytics: false,
          firebaseProjectId: 'lizascookies-dev',
        );
        break;
      case AppFlavor.staging:
        _instance = const AppConfig(
          flavor: AppFlavor.staging,
          appName: 'LizasCookies Staging',
          baseUrl: 'https://staging.lizascookies.id',
          apiVersion: 'v1',
          enableLogging: true,
          enableCrashlytics: true,
          firebaseProjectId: 'lizascookies-staging',
        );
        break;
      case AppFlavor.prod:
        _instance = const AppConfig(
          flavor: AppFlavor.prod,
          appName: 'LizasCookies',
          baseUrl: 'https://api.lizascookies.id',
          apiVersion: 'v1',
          enableLogging: false,
          enableCrashlytics: true,
          firebaseProjectId: 'lizascookies-prod',
        );
        break;
    }
  }
}

// App constants
class AppConstants {
  static const String appPackageName = 'com.lizascookies';
  static const String deepLinkScheme = 'lizascookies';
  
  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userProfileKey = 'user_profile';
  static const String fcmTokenKey = 'fcm_token';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String themeModeKey = 'theme_mode';
  static const String languageCodeKey = 'language_code';
  
  // Hive boxes
  static const String cartBoxName = 'cart';
  static const String productsCacheBoxName = 'products_cache';
  static const String categoriesCacheBoxName = 'categories_cache';
  static const String addressesBoxName = 'addresses';
  static const String notificationsBoxName = 'notifications';
  static const String syncQueueBoxName = 'sync_queue';
  static const String offlineStockBoxName = 'offline_stock';
  static const String offlineOrdersBoxName = 'offline_orders';
  static const String syncHistoryBoxName = 'sync_history';
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;
  
  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 15);
  
  // Retry
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  
  // Image
  static const String placeholderImage = 'assets/images/placeholder.png';
  static const String errorImage = 'assets/images/error.png';
  
  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Notification channels
  static const String orderUpdatesChannelId = 'order_updates';
  static const String promoChannelId = 'promo';
  static const String generalChannelId = 'general';
}