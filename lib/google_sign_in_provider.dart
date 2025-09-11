import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInProvider {
  static final GoogleSignIn instance = GoogleSignIn(
    serverClientId: "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com", // 👈 from Google Cloud OAuth
    scopes: ['email', 'profile'],
  );
}
