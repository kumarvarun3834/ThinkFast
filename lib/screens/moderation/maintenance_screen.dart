import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinkfast/utils/global.dart' as global;

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Show bypass button if user is a registered admin, regardless of current "Admin Mode" toggle
    final bool isUserAdmin =
        global.isAdmin ||
        global.isRegisteredAdmin ||
        (global.currentUserProfile?['role'] == 'admin');

    return Scaffold(
      backgroundColor: global.bgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.build_rounded,
                size: 80,
                color: global.primaryAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                "Under Maintenance",
                style: TextStyle(
                  color: global.valueColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "We are currently updating ThinkFast to provide a better experience. We'll be back shortly!",
                textAlign: TextAlign.center,
                style: TextStyle(color: global.labelColor, fontSize: 16),
              ),
              if (isUserAdmin) ...[
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: global.btnColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.admin_panel_settings_rounded),
                  label: const Text(
                    "BYPASS AS ADMIN",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Maintenance mode is active, but you have admin privileges.",
                  style: TextStyle(
                    color: global.labelColor.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
              if (user == null) ...[
                const SizedBox(height: 40),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  icon: const Icon(Icons.login_rounded, color: global.primaryAccent),
                  label: const Text(
                    "ADMIN LOGIN",
                    style: TextStyle(
                      color: global.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
