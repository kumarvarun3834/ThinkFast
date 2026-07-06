import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:thinkfast/auth/auth_service.dart';
import 'package:thinkfast/main.dart'; // To access navigatorKey
import 'package:thinkfast/services/device_service.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final DeviceService _deviceService = DeviceService();
  final AuthService _authService = AuthService();
  StreamSubscription? _deviceSubscription;

  void startDeviceTracking() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _listenToActiveDevice(user.uid);
      } else {
        _stopListening();
      }
    });
  }

  void _listenToActiveDevice(String userId) async {
    final currentDeviceId = await _deviceService.getDeviceId();
    bool hasEstablished = false;

    _deviceSubscription?.cancel();
    _deviceSubscription = _deviceService
        .watchActiveDevice(userId)
        .listen((activeDeviceId) {
      // 1. Only start enforcing logout AFTER this device has successfully 
      // become the active device in Firestore at least once.
      if (activeDeviceId == currentDeviceId) {
        hasEstablished = true;
      }

      // 2. If we were established and the ID changes to something else, logout.
      if (hasEstablished &&
          activeDeviceId != null &&
          activeDeviceId != currentDeviceId) {
        _handleOtherDeviceLogin();
      }
    });
  }

  void _stopListening() {
    _deviceSubscription?.cancel();
    _deviceSubscription = null;
  }

  void _handleOtherDeviceLogin() async {
    _stopListening();
    
    // Log out locally
    await _authService.logout();

    // Show dialog and redirect to login
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Logged Out", style: TextStyle(color: Colors.white)),
          content: const Text(
            "You have been logged out because another device logged into your account.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }
}
