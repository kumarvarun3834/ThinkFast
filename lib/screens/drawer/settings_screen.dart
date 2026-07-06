import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        title: Text(
          "SETTINGS",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null) ...[
            _buildSectionHeader("Account"),
            _buildSettingsTile(
              icon: Icons.account_circle_outlined,
              title: "Profile",
              subtitle: "Manage your personal information",
              onTap: () => Navigator.pushNamed(context, "/profile"),
            ),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader("Information"),
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            title: "About Us",
            subtitle: "Learn more about ThinkFast",
            onTap: () => Navigator.pushNamed(context, "/About Us"),
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: "Privacy Policy",
            subtitle: "Read our privacy guidelines",
            onTap: () => Navigator.pushNamed(context, "/Privacy Policy"),
          ),
          const SizedBox(height: 24),
          if (user != null) ...[
            _buildSectionHeader("Session"),
            _buildSettingsTile(
              icon: Icons.logout_rounded,
              title: "Logout",
              subtitle: "Sign out of your account",
              textColor: global.errorColor,
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          color: global.primaryAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: global.primaryAccent),
        title: Text(
          title,
          style: TextStyle(
            color: textColor ?? global.valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: global.labelColor, fontSize: 12),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: global.labelColor,
        ),
      ),
    );
  }
}
