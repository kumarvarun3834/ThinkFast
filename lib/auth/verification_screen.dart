import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final AuthService auth = AuthService();

  bool loading = false;
  Timer? _timer;

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

        Navigator.pushReplacementNamed(context, '/home');
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Email")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_read, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "Verify your email",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "We have sent a verification link to your email.\n"
              "Please verify to continue.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () => checkVerification(),
                    child: const Text("I Verified"),
                  ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: resendEmail,
              child: const Text("Resend Email"),
            ),
            TextButton(
              onPressed: () {
                auth.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text("Back to Login"),
            ),
          ],
        ),
      ),
    );
  }
}
