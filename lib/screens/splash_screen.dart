import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/global.dart' as global;
import '../widgets/image_container.dart';

/// SPLASH SCREEN
class MySplash extends StatefulWidget {
  const MySplash({super.key});

  @override
  State<MySplash> createState() => _MySplashState();
}

class _MySplashState extends State<MySplash> {
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _hasError = false;
      _errorMessage = "";
    });

    // Minimum splash duration
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final navigator = Navigator.of(context);
    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user != null) {
        await global.db.initAppData(user.uid);
      } else {
        // If not logged in, still fetch flags for maintenance check
        global.featureFlags = await global.db.getFeatureFlags();
      }

      // Ensure we have some default flags if fetch returns null
      global.featureFlags ??= {
        'maintenance_mode': false,
        'enable_login': true,
        'enable_signup': true,
        'enable_ai': true,
        'enable_import': false,
        'enable_create_quiz': true,
        'enable_export': true,
        'enable_take_quiz': true,
      };
    } catch (e) {
      debugPrint("Initialization error: $e");
      // Ensure default flags even on total failure
      global.featureFlags ??= {
        'maintenance_mode': false,
        'enable_login': true,
        'enable_signup': true,
        'enable_ai': true,
        'enable_import': false,
        'enable_create_quiz': true,
        'enable_export': true,
        'enable_take_quiz': true,
      };
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString().contains("network")
              ? "Network error. Please check your internet connection."
              : "Server connection failed. Please try again.";
        });
      }
      return;
    }

    if (!mounted) return;

    final bool isMaintenance =
        global.featureFlags?['maintenance_mode'] == true;

    if (isMaintenance && !global.isAdmin) {
      navigator.pushReplacementNamed('/maintenance');
      return;
    }

    if (user != null) {
      final isBanned = await global.db.isUserBanned(user.uid);
      if (isBanned && !global.isAdmin) {
        // Get reason if possible
        String? reason;
        try {
          final banDoc = await FirebaseFirestore.instance
              .collection('banned_users')
              .doc('global_${user.uid}')
              .get();
          if (banDoc.exists) {
            reason = banDoc.data()?['reason'];
          }
        } catch (_) {}

        if (mounted) {
          navigator.pushReplacementNamed(
            '/banned',
            arguments: reason,
          );
        }
        return;
      }
      navigator.pushReplacementNamed('/home');
    } else {
      navigator.pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ImageContainer(
                "assets/images/quiz-logo.png",
                global.valueColor.withValues(alpha: 0.1),
                350,
                300,
              ),
              const SizedBox(height: 40),
              if (_hasError) ...[
                const Icon(
                  Icons.cloud_off_rounded,
                  color: global.errorColor,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: global.labelColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _initializeApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: global.btnColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    "RECHECK SERVER",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ] else
                const CircularProgressIndicator(color: global.primaryAccent),
            ],
          ),
        ),
      ),
    );
  }
}
