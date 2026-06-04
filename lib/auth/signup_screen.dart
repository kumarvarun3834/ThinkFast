import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService auth = AuthService();
  bool loading = false;

  void signup() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _show("Please fill all fields");
      return;
    }

    setState(() => loading = true);

    try {
      final user = await auth.signUp(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user != null) {
        // optionally store name in Firebase Auth
        await user.updateDisplayName(nameController.text.trim());
        
        if (mounted) {
          _show("Signup successful! Please verify your email.");
          Navigator.pushReplacementNamed(context, '/verify');
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
                color: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Color(0xFFE2E8F0)),
              decoration: InputDecoration(
                labelText: "Full Name",
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF3B82F6)),
                ),
                prefixIcon: const Icon(Icons.person, color: Color(0xFF3B82F6)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Color(0xFFE2E8F0)),
              decoration: InputDecoration(
                labelText: "Email",
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF3B82F6)),
                ),
                prefixIcon: const Icon(Icons.email, color: Color(0xFF3B82F6)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Color(0xFFE2E8F0)),
              decoration: InputDecoration(
                labelText: "Password",
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF3B82F6)),
                ),
                prefixIcon: const Icon(Icons.lock, color: Color(0xFF3B82F6)),
              ),
            ),
            const SizedBox(height: 30),
            loading
                ? const CircularProgressIndicator(color: Color(0xFF3B82F6))
                : SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text("SIGN UP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ),
                  ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account?", style: TextStyle(color: Color(0xFF94A3B8))),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text("Login", style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
