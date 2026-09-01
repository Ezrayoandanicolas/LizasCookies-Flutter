import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

class AppUpdateInfo {
  final String version;
  final int build;
  final String? downloadUrl;
  final String changelog;
  final bool forceUpdate;

  const AppUpdateInfo({
    required this.version,
    required this.build,
    this.downloadUrl,
    this.changelog = '',
    this.forceUpdate = false,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final buildVal = json['build'];
    return AppUpdateInfo(
      version: json['version']?.toString() ?? '1.0.0',
      build: buildVal is int ? buildVal : int.tryParse(buildVal.toString()) ?? 1,
      downloadUrl: json['download_url']?.toString(),
      changelog: json['changelog']?.toString() ?? '',
      forceUpdate: json['force_update'] == true,
    );
  }

  bool get needsUpdate {
    final current = _currentVersion;
    if (current == null) return false;

    // Compare build number first (more reliable)
    final currentBuild = int.tryParse(current.buildNumber) ?? 0;
    if (build > currentBuild) return true;

    // Compare version string
    return _isNewerVersion(version, current.version);
  }

  static PackageInfo? _cachedInfo;
  static PackageInfo? get _currentVersion => _cachedInfo;

  static Future<void> init() async {
    _cachedInfo = await PackageInfo.fromPlatform();
  }

  static bool _isNewerVersion(String newVersion, String currentVersion) {
    final newParts = newVersion.split('.').map(int.tryParse).whereType<int>().toList();
    final curParts = currentVersion.split('.').map(int.tryParse).whereType<int>().toList();

    for (var i = 0; i < 3; i++) {
      final n = i < newParts.length ? newParts[i] : 0;
      final c = i < curParts.length ? curParts[i] : 0;
      if (n > c) return true;
      if (n < c) return false;
    }
    return false;
  }
}

class OtaService {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  /// Check for update from server
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final response = await _dio.get(
        '${AppConfig.instance.apiBaseUrl}/public/app-version',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final info = AppUpdateInfo.fromJson(response.data as Map<String, dynamic>);
      if (info.needsUpdate && info.downloadUrl != null) {
        return info;
      }
      return null;
    } catch (e) {
      debugPrint('OTA check failed: $e');
      return null;
    }
  }

  /// Download APK and install
  Future<void> downloadAndInstall(
    String downloadUrl,
    void Function(double progress)? onProgress,
  ) async {
    _cancelToken = CancelToken();

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/lizas_update.apk';

    await _dio.download(
      downloadUrl,
      filePath,
      cancelToken: _cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    // Open APK for installation
    final result = await OpenFile.open(filePath);
    if (result.type != ResultType.done) {
      debugPrint('Failed to open APK: ${result.message}');
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel('User cancelled');
  }

  void dispose() {
    cancelDownload();
  }
}
