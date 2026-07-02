import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinkfast/utils/global.dart' as global;

class BanScreen extends StatelessWidget {
  final String? reason;
  const BanScreen({super.key, this.reason});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.gavel_rounded,
                color: global.errorColor,
                size: 80,
              ),
              const SizedBox(height: 32),
              Text(
                "ACCESS DENIED",
                style: GoogleFonts.poppins(
                  color: global.errorColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "You have been permanently banned from ThinkFast for violating our terms of service.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: global.valueColor,
                  fontSize: 16,
                ),
              ),
              if (reason != null && reason!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: global.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: global.errorColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    "Reason: $reason",
                    style: const TextStyle(color: global.errorColor, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 48),
              Text(
                "If you believe this is a mistake, please contact support or try creating an account with another email.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: global.labelColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Logic to open email client or report form
                  },
                  icon: const Icon(Icons.report_problem_outlined, size: 18),
                  label: const Text("REPORT AN ISSUE"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: global.errorColor.withOpacity(0.1),
                    foregroundColor: global.errorColor,
                    side: BorderSide(color: global.errorColor.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Logic to open report form or email
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Redirecting to support...")),
                    );
                  },
                  icon: const Icon(Icons.report_problem_outlined, size: 20, color: global.errorColor),
                  label: const Text("REPORT AN ISSUE / APPEAL"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: global.errorColor.withOpacity(0.1),
                    foregroundColor: global.errorColor,
                    side: BorderSide(color: global.errorColor.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: global.cardColor,
                    side: const BorderSide(color: global.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text("BACK TO LOGIN"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
