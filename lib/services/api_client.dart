import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ApiClient {
  static final Dio _dio = _initDio();

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
            final appCheckToken = await FirebaseAppCheck.instance.getToken();
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

  /// 🔐 Builds a hardened security payload for AI backend requests
  static Future<Map<String, dynamic>> buildSecurityPayload(
    Map<String, dynamic> requestData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    // Default values
    String? firebaseIdToken;
    String? appCheckToken;

    // Fetch tokens once (Interceptor will also fetch but App Check caches internally)
    try {
      // Force refresh both tokens to ensure backend gets a valid cryptographic attestation
      firebaseIdToken = await user?.getIdToken(true); 
      
      appCheckToken = await FirebaseAppCheck.instance.getToken();
      if (appCheckToken == null) {
        debugPrint("App Check: Initial fetch returned null, attempting force refresh...");
        appCheckToken = await FirebaseAppCheck.instance.getToken(true);
      }

      if (appCheckToken == null) {
        debugPrint("App Check: Token is still null. Verify Device Check/Play Integrity registration in Firebase.");
      } else {
        debugPrint("App Check: Token successfully retrieved.");
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
