import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ApiClient {
  static final Dio _dio = _initDio();

  // Local cache to reduce frequency of App Check attestation requests
  static String? _cachedAppCheckToken;
  static DateTime? _lastTokenFetch;

  static Dio _initDio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final user = FirebaseAuth.instance.currentUser;
          final token = await user?.getIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          try {
            final appCheckToken = await _getAppCheckToken();
            if (appCheckToken != null) {
              options.headers['X-Firebase-AppCheck'] = appCheckToken;
            }
          } catch (_) {}

          return handler.next(options);
        },
      ),
    );
    return dio;
  }

  static Dio get instance => _dio;

  static Future<String?> _getAppCheckToken() async {
    final now = DateTime.now();
    // Use local cache for 5 minutes to prevent "Too many attempts" errors
    if (_cachedAppCheckToken != null && _lastTokenFetch != null) {
      if (now.difference(_lastTokenFetch!).inMinutes < 5) {
        return _cachedAppCheckToken;
      }
    }

    try {
      _cachedAppCheckToken = await FirebaseAppCheck.instance.getToken();
      _lastTokenFetch = now;
      return _cachedAppCheckToken;
    } catch (e) {
      debugPrint("App Check token error: $e");
      return _cachedAppCheckToken; // Return last known good token on error
    }
  }

  /// 🔐 Builds a hardened security payload for AI backend requests
  static Future<Map<String, dynamic>> buildSecurityPayload(
    Map<String, dynamic> requestData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    // Default values
    String? firebaseIdToken;
    String? appCheckToken;

    // Fetch tokens once
    try {
      firebaseIdToken = await user?.getIdToken();
      appCheckToken = await _getAppCheckToken();

      if (appCheckToken == null) {
        debugPrint("App Check: Token is null.");
      } else {
        debugPrint("App Check: Token retrieved.");
      }
    } catch (e) {
      debugPrint("Security token fetch error: $e");
    }

    // Get Device ID (Cross-platform)
    String deviceId = "unknown_device";
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = webInfo.userAgent ?? "web_browser";
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? "unknown_ios";
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        deviceId = winInfo.deviceId;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceId = macInfo.systemGUID ?? "unknown_macos";
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        deviceId = linuxInfo.machineId ?? "unknown_linux";
      }
    } catch (e) {
      debugPrint("Device Info error: $e");
    }

    // Get App Version
    String appVersion = "1.0.0";
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
    } catch (e) {
      debugPrint("Package Info error: $e");
    }

    return {
      "firebaseIdToken": firebaseIdToken,
      "appCheckToken": appCheckToken,
      "deviceId": deviceId,
      "appVersion": appVersion,
      "uuid": user?.uid ?? "",
      "email": user?.email ?? "",
      "name": user?.displayName ?? "",
      "quizRequest": requestData,
    };
  }
}
