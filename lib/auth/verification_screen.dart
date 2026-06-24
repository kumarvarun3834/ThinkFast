import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final AuthService auth = AuthService();

  bool loading = false;
  Timer? _timer;

  // Colors (Synced with Global Palette)
  final Color _bgColor = global.bgColor;
  final Color _cardColor = global.cardColor;
  final Color _primaryAccent = global.primaryAccent;
  final Color _labelColor = global.labelColor;
  final Color _valueColor = global.valueColor;
  final Color _btnColor = global.btnColor;
  final Color _borderColor = global.borderColor;

  @override
  void initState() {
    super.initState();

    /// 🔁 Auto check every 4 seconds
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      checkVerification(auto: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// ---------------- CHECK VERIFICATION ----------------
  Future<void> checkVerification({bool auto = false}) async {
    if (!auto) setState(() => loading = true);

    try {
      await auth.reloadUser();
      final user = auth.user;

      if (user != null && user.emailVerified) {
        _timer?.cancel();

        if (!mounted) return;

        setState(() => loading = false);

        Navigator.pushReplacementNamed(context, '/profile');
      } else {
        if (!auto) {
          setState(() => loading = false);
          _show("Still not verified");
        }
      }
    } catch (e) {
      if (!auto) {
        setState(() => loading = false);
        _show("Check failed: $e");
      }
    }
  }

  /// ---------------- RESEND EMAIL ----------------
  Future<void> resendEmail() async {
    try {
      await auth.resendVerificationEmail();
      _show("Verification email sent again");
    } catch (e) {
      _show("Failed to resend email: $e");
    }
  }

  /// ---------------- SNACKBAR ----------------
  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: _cardColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Verify Email",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _valueColor,
          ),
        ),
        // actions: [
        //   TextButton(
        //     onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        //     child: Text(
        //       "SKIP",
        //       style: TextStyle(
        //         color: _primaryAccent,
        //         fontWeight: FontWeight.bold,
        //       ),
        //     ),
        //   ),
        // ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.mark_email_read_rounded,
                      size: 100,
                      color: _primaryAccent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Almost There!",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _valueColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "We've sent a verification link to your email address. Please click it to activate your account.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: _labelColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    loading
                        ? CircularProgressIndicator(color: _primaryAccent)
                        : ElevatedButton(
                            onPressed: () => checkVerification(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _btnColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: Text(
                              "I'VE VERIFIED",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: resendEmail,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryAccent,
                        minimumSize: const Size(double.infinity, 56),
                        side: BorderSide(color: _borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "RESEND EMAIL",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: () {
                  auth.logout();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: _labelColor,
                  size: 20,
                ),
                label: Text(
                  "Back to Login",
                  style: GoogleFonts.poppins(
                    color: _labelColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
            ],
          ),
        ),
      ),
    );
  }
}
