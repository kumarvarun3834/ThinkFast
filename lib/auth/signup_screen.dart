import 'package:flutter/material.dart';
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
      appBar: AppBar(title: const Text("Sign Up")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              "Create Account",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 30),
            loading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: signup,
                      child: const Text("Sign Up", style: TextStyle(fontSize: 18)),
                    ),
                  ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account?"),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text("Login"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
