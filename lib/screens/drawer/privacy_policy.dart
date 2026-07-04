import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  final Color _bgColor = global.bgColor;
  final Color _cardColor = global.cardColor;
  final Color _primaryAccent = global.primaryAccent;
  final Color _valueColor = global.valueColor;
  final Color _labelColor = global.labelColor;
  final Color _borderColor = global.borderColor;

  Widget _buildSectionTitle(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color ?? _primaryAccent,
        ),
      ),
    );
  }

  Widget _buildContentText(String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        content,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: _labelColor,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildPolicyContainer({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (accentColor ?? _borderColor).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor ?? _primaryAccent, size: 24),
              const SizedBox(width: 12),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: accentColor ?? _primaryAccent,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Divider(height: 32, color: global.borderColor),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = global.currentUserProfile;
    final int userAge = int.tryParse(profile?['age']?.toString() ?? '13') ?? 13;
    final bool isMinor = userAge < 13;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          "PRIVACY CENTER",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _valueColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 20),
              child: Text(
                "Last Updated: July 2024",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: _labelColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // CONTAINER 1: CORE APP USAGE
            _buildPolicyContainer(
              title: "Standard App Usage",
              icon: Icons.security_rounded,
              children: [
                _buildSectionTitle("1. Information We Collect"),
                _buildContentText(
                  "To provide our core services, we collect your name and email address during registration. "
                  "We also track your quiz attempts, results, and reporting activity to maintain your history and platform integrity.",
                ),
                _buildSectionTitle("2. Data Protection"),
                _buildContentText(
                  "All data is transmitted over secure connections and stored in encrypted Firestore databases. "
                  "Access is restricted via granular security rules, ensuring only you (and authorized admins) can see your private data.",
                ),
                _buildSectionTitle("3. Your Rights"),
                _buildContentText(
                  "You have the right to view and update your profile at any time. "
                  "Unverified accounts are automatically purged after 7 days for your security.",
                ),
              ],
            ),

            // CONTAINER 2: AI & PERSONALIZATION
            if (!isMinor)
              _buildPolicyContainer(
                title: "AI & Personalization",
                icon: Icons.auto_awesome_rounded,
                accentColor: Colors.purpleAccent,
                children: [
                  _buildSectionTitle("1. Optional AI Analysis", color: Colors.purpleAccent),
                  _buildContentText(
                    "If you explicitly 'Opt-in', we collect and analyze your Age, Grade, Study Goals, and Learning Style. "
                    "This data is used solely to train our local AI models to generate quizzes that match your educational level.",
                  ),
                  _buildSectionTitle("2. Data Minimization", color: Colors.purpleAccent),
                  _buildContentText(
                    "If you choose not to opt-in, or if you are under 13, this data is NEVER collected or stored. "
                    "You can withdraw your consent at any time via the Profile screen, which will instantly clear this data from our servers.",
                  ),
                  _buildSectionTitle("3. AI Guardrails", color: Colors.purpleAccent),
                  _buildContentText(
                    "We use professional-grade AI models with strict safety prompts to ensure generated content is educational, "
                    "safe, and free from inappropriate material.",
                  ),
                ],
              ),

            if (isMinor)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.child_care_rounded, color: Colors.orangeAccent, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Personalization features are restricted for users under 13 to ensure a safe learning environment.",
                        style: GoogleFonts.poppins(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            Center(
              child: Text(
                "For more details, contact support@thinkfast.app",
                style: GoogleFonts.poppins(fontSize: 12, color: _labelColor),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                "© 2024 ThinkFast. Challenge Your Mind.",
                style: GoogleFonts.poppins(fontSize: 10, color: _labelColor.withValues(alpha: 0.7)),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
          ],
        ),
      ),
    );
  }
}
