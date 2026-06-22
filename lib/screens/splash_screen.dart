import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firebase_direct_commands.dart';
import '../widgets/ImageContainer.dart';
import '../utils/global.dart' as global;

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
          final db = DatabaseService();

          if (user != null) {
            await db.initAppData(user.uid);
          } else {
            // If not logged in, still fetch flags for maintenance check
            global.featureFlags = await db.getFeatureFlags();
          }
        } catch (e) {
          debugPrint("Initialization error: $e");
          // Ensure we have some default flags even on total failure
          global.featureFlags ??= {
            'maintenance_mode': false,
            'enable_login': true,
          };
        }

        if (!mounted) return;

        final bool isMaintenance = global.featureFlags?['maintenance_mode'] == true;

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
