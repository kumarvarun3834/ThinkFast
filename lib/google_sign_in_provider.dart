import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInProvider {
  // 1. Create a private static instance of the class
  static final GoogleSignInProvider _instance = GoogleSignInProvider._internal();

  // 2. Create a factory constructor to return the singleton instance
  factory GoogleSignInProvider() {
    return _instance;
  }

  // 3. Private constructor to prevent direct instantiation
  GoogleSignInProvider._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
    serverClientId: '775124683303-g0rnar32rjagj6kpn5fq82945rkbtofe.apps.googleusercontent.com',
  );

  GoogleSignIn get instance => _googleSignIn;

  Future<void> initialize() async {
    await _googleSignIn.initialize();
  }
}