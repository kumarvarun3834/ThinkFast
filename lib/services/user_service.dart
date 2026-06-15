import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class UserService {
  final CollectionReference _users = FirebaseFirestore.instance.collection('users');

  /// ✅ Create a new user profile
  Future<void> createUserProfile({
    required String uid,
    required String email,
    String? name,
  }) async {
    // 1. Public Profile (Accessible by anyone)
    await _users.doc(uid).set({
      'name': name ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
      'quizCount': 0,
      'attemptCount': 0,
    }, SetOptions(merge: true));

    // 2. Private Data (Accessible only by the owner)
    await _users.doc(uid).collection('private').doc('details').set({
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ Fetch user profile by UID (Combines Public, Protected, and Private)
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;

      // Fetch protected data
      final protectedDoc = await _users.doc(uid).collection('protected').doc('details').get();
      if (protectedDoc.exists) {
        data.addAll(protectedDoc.data() as Map<String, dynamic>);
      }

      // Fetch private data
      final privateDoc = await _users.doc(uid).collection('private').doc('details').get();
      if (privateDoc.exists) {
        data.addAll(privateDoc.data() as Map<String, dynamic>);
      }

      return data;
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      return null;
    }
  }

  /// ✅ Update user public profile
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? photoUrl,
    String? bio,
  }) async {
    final Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) updates['name'] = name;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (bio != null) updates['bio'] = bio;

    await _users.doc(uid).set(updates, SetOptions(merge: true));
  }

  /// ✅ Update user protected details (AI context)
  Future<void> updateProtectedDetails({
    required String uid,
    Map<String, dynamic>? details,
  }) async {
    if (details == null) return;
    details['updatedAt'] = FieldValue.serverTimestamp();
    await _users.doc(uid).collection('protected').doc('details').set(details, SetOptions(merge: true));
  }

  /// ✅ Update user private details (Email, activeQuizId etc.)
  Future<void> updatePrivateDetails({
    required String uid,
    String? email,
    String? activeQuizId,
    DateTime? activeQuizExpiry,
    bool clearActiveQuiz = false,
  }) async {
    final Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (email != null) updates['email'] = email;
    if (clearActiveQuiz) {
      updates['activeQuizId'] = FieldValue.delete();
      updates['activeQuizExpiry'] = FieldValue.delete();
    } else {
      if (activeQuizId != null) updates['activeQuizId'] = activeQuizId;
      if (activeQuizExpiry != null) updates['activeQuizExpiry'] = Timestamp.fromDate(activeQuizExpiry);
    }

    await _users.doc(uid).collection('private').doc('details').set(updates, SetOptions(merge: true));
  }
}
