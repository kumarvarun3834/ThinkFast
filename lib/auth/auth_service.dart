import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:thinkfast/services/api_client.dart';
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
      final response = await ApiClient.instance.get('https://api64.ipify.org');
      if (response.statusCode == 200) {
        return response.data.toString().trim();
      }
    } catch (_) {}
    return "unknown_ip";
  }

  /// ---------------- CURRENT USER ----------------
  User? get user => _auth.currentUser;

  /// ---------------- SIGN UP WITH EMAIL ----------------
  Future<User?> signUp(
    String email,
    String password, {
    String? name,
    bool force = false,
  }) async {
    try {
      final res = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = res.user;

      if (user != null) {
        // Create user profile in Firestore (Pass name if available)
        await global.db.createUserProfile(
          uid: user.uid,
          email: user.email ?? email,
          name: name,
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
  Future<User?> login(
    String email,
    String password, {
    bool force = false,
  }) async {
    final ip = await _getPublicIP();
    final ipRef = _db.collection('security_logs').doc('ip_$ip');

    // Check if IP is flagged (Safe read for non-admins)
    try {
      final snapshot = await ipRef.get();
      if (snapshot.exists) {
        final data = snapshot.data()!;
        if (data['is_blocked'] == true) {
          throw "too_many_attempts_ip_blocked";
        }

        // Auto-unblock after 1 hour
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
    } catch (e) {
      if (e == "too_many_attempts_ip_blocked") rethrow;
      // Ignore read errors (like permission denied) to allow login to proceed
      debugPrint("Security IP check skipped: $e");
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
      // Increment failed count (Safe write - security_logs allows public create/update)
      try {
        await ipRef.set({
          'attemptCount': FieldValue.increment(1),
          'lastAttempt': FieldValue.serverTimestamp(),
          'last_email_tried': email,
          'ip': ip,
          'action': 'failed_login',
        }, SetOptions(merge: true));

        // Re-fetch to check if we just hit the limit (This might still fail if not admin,
        // but we'll ignore it as the next login call will handle it)
        final updated = await ipRef.get();
        if (updated.exists && (updated.data()?['attemptCount'] ?? 0) >= 5) {
          await ipRef.update({
            'is_blocked': true,
            'action': 'blocked_access',
            'blockedUntil': Timestamp.fromDate(
              DateTime.now().add(const Duration(hours: 1)),
            ),
          });
          throw "too_many_attempts_ip_blocked";
        }
      } catch (logError) {
        debugPrint("Failed to log security attempt: $logError");
      }

      throw e.code;
    } catch (e) {
      if (e == 'session_conflict' ||
          e == 'account_deleted_unverified' ||
          e == 'too_many_attempts_ip_blocked') {
        rethrow;
      }
      throw "login_failed";
    }
  }

  /// ---------------- GOOGLE SIGN IN ----------------
  Future<User?> signInWithGoogle({bool force = false}) async {
    try {
      if (kIsWeb) {
        // On Web, we use Firebase's native Popup for better compatibility
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _auth.signInWithPopup(
          googleProvider,
        );
        final user = userCredential.user;

        if (user != null) {
          await global.db.createUserProfile(
            uid: user.uid,
            email: user.email ?? '',
            name: user.displayName,
            photoUrl: user.photoURL,
          );
          await _deviceService.updateActiveDevice(user.uid);
        }
        return user;
      }

      // Trigger the authentication flow on Mobile (Google Sign In 7.2.0+)
      // Note: authenticate() throws on cancel, unlike legacy signIn() which returned null.
      GoogleSignInAccount googleAccount;
      try {
        googleAccount = await _googleSignIn.authenticate();
      } catch (e) {
        // Handle User Cancelled or other sign-in errors gracefully
        debugPrint("Google Sign In Cancelled or Failed: $e");
        return null;
      }

      // Obtain the auth details from the account (getter in 7.2.0)
      final GoogleSignInAuthentication googleAuth =
          googleAccount.authentication;

      if (googleAuth.idToken == null) {
        throw "google_id_token_missing";
      }

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
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
      debugPrint("Google Auth Firebase Error: ${e.code}");
      throw e.code;
    } catch (e) {
      debugPrint("Google Sign In Generic Error: $e");
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

  /// ---------------- PASSWORD RESET ----------------
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw "reset_failed";
    }
  }

  /// ---------------- REAUTHENTICATE ----------------
  Future<void> reauthenticate(String email, String password) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await _auth.currentUser?.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw "reauth_failed";
    }
  }

  /// ---------------- UPDATE EMAIL ----------------
  Future<void> updateEmail(String newEmail) async {
    try {
      // Modern flow: Sends verification to new email, updates once verified
      await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw "update_email_failed";
    }
  }

  /// ---------------- LINK WITH GOOGLE ----------------
  Future<User?> linkWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw "no_user";

    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential credential = await user.linkWithPopup(
          googleProvider,
        );
        return credential.user;
      }

      final GoogleSignInAccount? googleAccount = await _googleSignIn
          .authenticate();
      if (googleAccount == null) return null;

      final GoogleSignInAuthentication googleAuth =
          googleAccount.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await user.linkWithCredential(
        credential,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw "link_google_failed";
    }
  }

  /// ---------------- LINK WITH EMAIL ----------------
  Future<User?> linkWithEmailPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw "no_user";

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      final UserCredential userCredential = await user.linkWithCredential(
        credential,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw "link_email_failed";
    }
  }

  /// ---------------- UNLINK PROVIDER ----------------
  Future<User?> unlinkProvider(String providerId) async {
    final user = _auth.currentUser;
    if (user == null) throw "no_user";

    // Safety check: Don't unlink the last provider
    if (user.providerData.length <= 1) {
      throw "cannot_unlink_last_provider";
    }

    try {
      final updatedUser = await user.unlink(providerId);
      return updatedUser;
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw "unlink_failed";
    }
  }

  /// ---------------- LOGOUT ----------------
  Future<void> logout() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _deviceService.clearActiveDevice(uid);
      }
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw "logout_failed";
    }
  }
}
