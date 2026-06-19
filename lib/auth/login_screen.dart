import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService auth = AuthService();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _fetchFlags();
  }

  Future<void> _fetchFlags() async {
    if (global.featureFlags == null) {
      await DatabaseService().getFeatureFlags();
    }
  }

  void login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _show("Please fill all fields");
      return;
    }

    setState(() => loading = true);

    try {
      final user = await auth.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user != null) {
        final db = DatabaseService();
        await db.initAppData(user.uid);

        // Check if login is enabled or if user is an admin
        final bool loginEnabled = global.featureFlags?['enable_login'] ?? true;
        final bool isAdmin = global.isAdmin || global.isRegisteredAdmin;

        if (!loginEnabled && !isAdmin) {
          await auth.logout();
          _show("Login is currently disabled by the administrator.");
          return;
        }

        if (!user.emailVerified) {
          Navigator.pushReplacementNamed(context, '/verify');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (e == 'user-not-found') {
        _show("User not found");
      } else if (e == 'wrong-password') {
        _show("Wrong password");
      } else if (e == 'invalid-email') {
        _show("Invalid email");
      } else {
        _show("Login failed: $e");
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void loginWithGoogle() async {
    setState(() => loading = true);
    try {
      final user = await auth.signInWithGoogle();
      if (user != null) {
        final db = DatabaseService();
        await db.initAppData(user.uid);

        // Check if login is enabled or if user is an admin
        final bool loginEnabled = global.featureFlags?['enable_login'] ?? true;
        final bool isAdmin = global.isAdmin || global.isRegisteredAdmin;

        if (!loginEnabled && !isAdmin) {
          await auth.logout();
          _show("Login is currently disabled by the administrator.");
          return;
        }

        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _show("Google Sign-In failed: $e");
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
        title: const Text("Login"),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            child: const Text(
              "SKIP",
              style: TextStyle(
                color: global.primaryAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              "Welcome Back",
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: global.valueColor,
              ),
            ),
            const SizedBox(height: 40),
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
            const SizedBox(height: 30),
            loading
                ? const CircularProgressIndicator(color: global.primaryAccent)
                : SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: global.btnColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "LOGIN",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 24),
            const Text("OR", style: TextStyle(color: global.labelColor)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: loginWithGoogle,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: global.borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Continue with Google",
                      style: TextStyle(fontSize: 16, color: global.valueColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account?",
                  style: TextStyle(color: global.labelColor),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(
                      color: global.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
