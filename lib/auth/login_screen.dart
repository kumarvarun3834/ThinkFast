import 'package:flutter/material.dart';
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
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _show("Google Sign-In failed: $e");
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
      appBar: AppBar(title: const Text("Login")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              "Welcome Back",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
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
                      onPressed: login,
                      child: const Text("Login", style: TextStyle(fontSize: 18)),
                    ),
                  ),
            const SizedBox(height: 20),
            const Text("OR"),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: loginWithGoogle,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image.network(
                    //   // 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                    //   "https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg",
                    //   height: 24,
                    // ),
                    // const SizedBox(width: 12),
                    const Flexible(
                      child: Text(
                        "Continue with Google",
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?"),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  child: const Text("Sign Up"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
