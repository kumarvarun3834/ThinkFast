import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ApiClient {
  static final Dio _dio = _initDio();

  // Local cache and locking to prevent "Too many attempts"
  static String? _cachedAppCheckToken;
  static DateTime? _lastTokenFetch;
  static Completer<String?>? _tokenCompleter;

  static Dio _initDio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final token = await user.getIdToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
              options.headers['x-user-uid'] = user.uid;
            }
          }

          try {
            final appCheckToken = await _getAppCheckToken();
            if (appCheckToken != null) {
              options.headers['X-Firebase-AppCheck'] = appCheckToken;
            }
          } catch (_) {}

          return handler.next(options);
        },
        onError: (DioException e, handler) {
          if (kIsWeb && e.type == DioExceptionType.connectionError) {
            debugPrint("--- SECURITY / CORS ERROR ---");
            debugPrint(
              "The request to ${e.requestOptions.path} was blocked by the browser.",
            );
            debugPrint(
              "Check your backend CORS configuration for allowed headers and origins.",
            );
            debugPrint(
              "Headers required: Content-Type, Authorization, X-Firebase-AppCheck",
            );
            debugPrint("-----------------------------");
          }
          return handler.next(e);
        },
      ),
    );
    return dio;
  }

  static Dio get instance => _dio;

  static Future<String?> _getAppCheckToken() async {
    // 1. Return from cache if recent (5 mins)
    final now = DateTime.now();
    if (_cachedAppCheckToken != null && _lastTokenFetch != null) {
      if (now.difference(_lastTokenFetch!).inMinutes < 5) {
        return _cachedAppCheckToken;
      }
    }

    // 2. If already fetching, wait for the result
    if (_tokenCompleter != null) {
      return _tokenCompleter!.future;
    }

    // 3. Start a new fetch session
    _tokenCompleter = Completer<String?>();
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      _cachedAppCheckToken = token;
      _lastTokenFetch = now;
      _tokenCompleter!.complete(token);
    } catch (e) {
      debugPrint("App Check token error: $e");
      _tokenCompleter!.complete(_cachedAppCheckToken); // Return old if fail
    } finally {
      _tokenCompleter = null; // Reset for next cycle
    }

    return _cachedAppCheckToken;
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
