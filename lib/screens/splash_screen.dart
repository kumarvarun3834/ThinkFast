import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/global.dart' as global;
import '../widgets/image_container.dart';

/// SPLASH SCREEN
class MySplash extends StatefulWidget {
  const MySplash({super.key});

  @override
  State<MySplash> createState() => _MySplashState();
}

class _MySplashState extends State<MySplash> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        try {
          if (user != null) {
            await global.db.initAppData(user.uid);
          } else {
            // If not logged in, still fetch flags for maintenance check
            global.featureFlags = await global.db.getFeatureFlags();
          }
        } catch (e) {
          debugPrint("Initialization error: $e");
          // Ensure we have some default flags even on total failure
          global.featureFlags ??= {
            'maintenance_mode': false,
            'enable_login': true,
            'enable_signup': true,
            'enable_ai': true,
            'enable_import': false,
            'enable_create_quiz': true,
            'enable_export': true,
          };
        }

        if (!mounted) return;

        final bool isMaintenance =
            global.featureFlags?['maintenance_mode'] == true;

        if (isMaintenance) {
          Navigator.pushReplacementNamed(context, '/maintenance');
        } else if (user != null) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ImageContainer(
              "assets/images/quiz-logo.png",
              global.valueColor.withOpacity(0.1),
              350,
              300,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: global.primaryAccent),
          ],
        ),
      ),
    );
  }
}
