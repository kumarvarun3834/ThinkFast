import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService auth = AuthService();
  bool loading = false;
  bool privacyPolicyAccepted = false;

  @override
  void initState() {
    super.initState();
    _fetchFlags();
  }

  Future<void> _fetchFlags() async {
    if (global.featureFlags == null) {
      await global.db.getFeatureFlags();
    }
  }

  void signup() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _show("Please fill all fields");
      return;
    }

    if (!privacyPolicyAccepted) {
      _show("Please accept the Privacy Policy to continue.");
      return;
    }

    setState(() => loading = true);

    try {
      final flags = global.featureFlags ?? await global.db.getFeatureFlags();

      if (flags?['enable_register'] == false) {
        _show("Registration is currently disabled by the administrator.");
        setState(() => loading = false);
        return;
      }

      final user = await auth.signUp(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user != null) {
        // optionally store name in Firebase Auth
        await user.updateDisplayName(nameController.text.trim());

        // Store privacy policy acceptance
        await global.db.updateProtectedDetails(
          uid: user.uid,
          details: {'privacyPolicyAccepted': true},
        );

        // Check if login is enabled
        await global.db.initAppData(user.uid);
        final bool loginEnabled = global.featureFlags?['enable_login'] ?? true;
        final bool isAdmin = global.isAdmin || global.isRegisteredAdmin;

        if (mounted) {
          if (!loginEnabled && !isAdmin) {
            await auth.logout();
            _show(
              "Account created! However, login is currently disabled by the administrator.",
            );
            Navigator.pushReplacementNamed(context, '/login');
          } else {
            _show("Signup successful! Please verify your email.");
            Navigator.pushReplacementNamed(context, '/verify');
          }
        }
      }
    } catch (e) {
      if (e == 'email-already-in-use') {
        _show("Email already in use");
      } else if (e == 'invalid-email') {
        _show("Invalid email");
      } else if (e == 'weak-password') {
        _show("Weak password");
      } else {
        _show("Signup failed: $e");
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Sign Up"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              "Create Account",
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: global.valueColor,
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: nameController,
              style: const TextStyle(color: global.valueColor),
              decoration: InputDecoration(
                labelText: "Full Name",
                labelStyle: const TextStyle(color: global.labelColor),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: global.borderColor),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: global.primaryAccent),
                ),
                prefixIcon: const Icon(Icons.person, color: global.primaryAccent),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              style: const TextStyle(color: global.valueColor),
              decoration: InputDecoration(
                labelText: "Email",
                labelStyle: const TextStyle(color: global.labelColor),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: global.borderColor),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: global.primaryAccent),
                ),
                prefixIcon: const Icon(Icons.email, color: global.primaryAccent),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: global.valueColor),
              decoration: InputDecoration(
                labelText: "Password",
                labelStyle: const TextStyle(color: global.labelColor),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: global.borderColor),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: global.primaryAccent),
                ),
                prefixIcon: const Icon(Icons.lock, color: global.primaryAccent),
              ),
            ),
            const SizedBox(height: 20),
            Theme(
              data: ThemeData(unselectedWidgetColor: global.labelColor),
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, "/Privacy Policy"),
                  child: Text(
                    "I accept the Privacy Policy",
                    style: GoogleFonts.poppins(
                      color: global.labelColor,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                value: privacyPolicyAccepted,
                onChanged: (val) {
                  setState(() {
                    privacyPolicyAccepted = val ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: global.primaryAccent,
                checkColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            loading
                ? const CircularProgressIndicator(color: global.primaryAccent)
                : SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: global.btnColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "SIGN UP",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Already have an account?",
                  style: TextStyle(color: global.labelColor),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text(
                    "Login",
                    style: TextStyle(
                      color: global.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
          ],
        ),
      ),
    );
  }
}
