import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:thinkfast/services/device_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DeviceService _deviceService = DeviceService();

  /// ---------------- GET PUBLIC IP ----------------
  Future<String> _getPublicIP() async {
    try {
      final response = await http.get(Uri.parse('https://api64.ipify.org'));
      if (response.statusCode == 200) {
        return response.body.trim();
      }
    } catch (_) {}
    return "unknown_ip";
  }

  /// ---------------- CURRENT USER ----------------
  User? get user => _auth.currentUser;

  /// ---------------- SIGN UP WITH EMAIL ----------------
  Future<User?> signUp(String email, String password, {bool force = false}) async {
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
          // Initialize last_resend_timestamp to now
          await _db
              .collection('users')
              .doc(user.uid)
              .collection('private')
              .doc('details')
              .set({
                'last_verification_resend': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }

        // Single Device Login: Update active device ID
        await _deviceService.updateActiveDevice(user.uid);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw e.code; // clean error pass
    } catch (e) {
      throw "signup_failed";
    }
  }

  /// ---------------- LOGIN WITH EMAIL ----------------
  Future<User?> login(String email, String password, {bool force = false}) async {
    final ip = await _getPublicIP();
    final ipRef = _db.collection('security_logs').doc('ip_$ip');

    // Check if IP is flagged
    final snapshot = await ipRef.get();
    if (snapshot.exists) {
      final data = snapshot.data()!;
      if (data['is_blocked'] == true) {
        throw "too_many_attempts_ip_blocked";
      }

      // Auto-unblock after 1 hour (Optional but good for UX)
      final Timestamp? lastAttempt = data['lastAttempt'];
      if (lastAttempt != null && (data['attemptCount'] ?? 0) >= 5) {
        final diff = DateTime.now().difference(lastAttempt.toDate());
        if (diff.inHours >= 1) {
          await ipRef.update({'attemptCount': 0, 'is_blocked': false});
        } else {
          throw "too_many_attempts_ip_blocked";
        }
      }
    }

    try {
      final res = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = res.user;

      if (user != null && !user.emailVerified) {
        final creationTime = user.metadata.creationTime;
        if (creationTime != null) {
          final diff = DateTime.now().difference(creationTime);
          if (diff.inDays >= 7) {
            // Unverified for more than a week -> Auto delete
            await user.delete();
            throw "account_deleted_unverified";
          }
        }
      }

      // Reset on success
      await ipRef.delete();

      if (user != null) {
        // Single Device Login: Check for conflict
        final hasConflict = await _deviceService.checkConflict(user.uid);
        if (hasConflict && !force) {
          throw "session_conflict";
        }
        await _deviceService.updateActiveDevice(user.uid);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      // Increment failed count
      await ipRef.set({
        'attemptCount': FieldValue.increment(1),
        'lastAttempt': FieldValue.serverTimestamp(),
        'last_email_tried': email,
        'ip': ip,
        'action': 'failed_login',
      }, SetOptions(merge: true));

      // Re-fetch to check if we just hit the limit
      final updated = await ipRef.get();
      if ((updated.data()?['attemptCount'] ?? 0) >= 5) {
        await ipRef.update({
          'is_blocked': true,
          'action': 'blocked_access',
          'blockedUntil': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 1)),
          ),
        });
        throw "too_many_attempts_ip_blocked";
      }

      throw e.code;
    } catch (e) {
      if (e == 'session_conflict' || e == 'account_deleted_unverified' || e == 'too_many_attempts_ip_blocked') {
        rethrow;
      }
      throw "login_failed";
    }
  }

  /// ---------------- GOOGLE SIGN IN ----------------
  Future<User?> signInWithGoogle({bool force = false}) async {
    try {
      // Trigger the authentication flow
      // Note: In google_sign_in 7.0.0+, you must call initialize() first if using custom config,
      // but here we use the default (configured via google-services.json on Android).
      // The method is now 'authenticate' for interactive sign-in.
      final GoogleSignInAccount googleAccount = await _googleSignIn
          .authenticate();

      // Obtain the auth details from the account
      final GoogleSignInAuthentication googleAuth =
          googleAccount.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        // Note: google_sign_in 7.0.0+ GoogleSignInAuthentication only has idToken.
        // If you need accessToken, you use authorizationClient.
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user != null) {
        // Create/Update user profile in Firestore
        await global.db.createUserProfile(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName,
          photoUrl: user.photoURL,
        );

        // Single Device Login: Check for conflict
        final hasConflict = await _deviceService.checkConflict(user.uid);
        if (hasConflict && !force) {
          throw "session_conflict";
        }

        await _deviceService.updateActiveDevice(user.uid);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Google Auth Error: ${e.code}");
      throw e.code;
    } catch (e) {
      // If user cancelled, authenticate() might throw or return something specific.
      // Based on the source, it rethrows GoogleSignInException.
      debugPrint("Google Sign In Error: $e");
      if (e == 'session_conflict') rethrow;
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

    // 5-minute cooldown check
    final privateRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('private')
        .doc('details');
    final snapshot = await privateRef.get();

    if (snapshot.exists) {
      final data = snapshot.data()!;
      final Timestamp? lastResend = data['last_verification_resend'];

      if (lastResend != null) {
        final diff = DateTime.now().difference(lastResend.toDate());
        if (diff.inMinutes < 5) {
          final remaining = 5 - diff.inMinutes;
          throw "Please wait $remaining minute(s) before resending.";
        }
      }
    }

    try {
      await user.sendEmailVerification();
      await privateRef.set({
        'last_verification_resend': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
