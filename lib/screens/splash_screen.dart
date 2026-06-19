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
        final db = DatabaseService();
        final user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          await db.initAppData(user.uid);
        } else {
          // If not logged in, still fetch flags for maintenance check
          global.featureFlags = await db.getFeatureFlags();
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
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ImageContainer(
              "assets/images/quiz-logo.png",
              const Color(0xFFE2E8F0).withOpacity(0.1),
              350,
              300,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Color(0xFF3B82F6)),
          ],
        ),
      ),
    );
  }
}
