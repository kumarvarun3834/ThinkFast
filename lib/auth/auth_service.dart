import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  /// ---------------- CURRENT USER ----------------
  User? get user => _auth.currentUser;

  /// ---------------- SIGN UP WITH EMAIL ----------------
  Future<User?> signUp(String email, String password) async {
    try {
      final res = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = res.user;

      if (user != null) {
        // Create user profile in Firestore
        await global.db.createUserProfile(
          uid: user.uid,
          email: user.email ?? email,
        );

        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw e.code; // clean error pass
    } catch (e) {
      throw "signup_failed";
    }
  }

  /// ---------------- LOGIN WITH EMAIL ----------------
  Future<User?> login(String email, String password) async {
    try {
      final res = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return res.user;
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw "login_failed";
    }
  }

  /// ---------------- GOOGLE SIGN IN ----------------
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      // Note: In google_sign_in 7.0.0+, you must call initialize() first if using custom config,
      // but here we use the default (configured via google-services.json on Android).
      // The method is now 'authenticate' for interactive sign-in.
      final GoogleSignInAccount googleAccount = await _googleSignIn.authenticate();

      // Obtain the auth details from the account
      final GoogleSignInAuthentication googleAuth = googleAccount.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        // Note: google_sign_in 7.0.0+ GoogleSignInAuthentication only has idToken.
        // If you need accessToken, you use authorizationClient.
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Create/Update user profile in Firestore
        await global.db.createUserProfile(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName,
          photoUrl: user.photoURL,
        );
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print(e.code);
      throw e.code;
    } catch (e) {
      // If user cancelled, authenticate() might throw or return something specific.
      // Based on the source, it rethrows GoogleSignInException.
      print(e);
      throw "google_sign_in_failed: $e";
    }
  }

  /// ---------------- CHECK EMAIL VERIFIED ----------------
  Future<bool> isEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      return false;
    }
  }

  /// ---------------- RESEND VERIFICATION ----------------
  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;

    if (user == null) throw "no_user";

    try {
      await user.sendEmailVerification();
    } catch (e) {
      throw "resend_failed";
    }
  }

  /// ---------------- RELOAD USER ----------------
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      throw "reload_failed";
    }
  }

  /// ---------------- LOGOUT ----------------
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw "logout_failed";
    }
  }
}
