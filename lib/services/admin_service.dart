import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final CollectionReference _admins = FirebaseFirestore.instance.collection('admins');
  final CollectionReference _reports = FirebaseFirestore.instance.collection('reports');
  final CollectionReference _auditLogs = FirebaseFirestore.instance.collection('audit_logs');
  final CollectionReference _quizAccess = FirebaseFirestore.instance.collection('quiz_access');

  /// ✅ Check if user is admin
  Future<bool> isAdmin(String uid) async {
    final doc = await _admins.doc(uid).get();
    return doc.exists;
  }

  /// ✅ Submit a report
  Future<void> submitReport({
    required String quizId,
    required String reportedBy,
    required String reason,
    required String description,
  }) async {
    await _reports.add({
      'quizId': quizId,
      'reportedBy': reportedBy,
      'reason': reason,
      'description': description,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Create Audit Log
  Future<void> logAction({
    required String actorId,
    required String action,
    required String targetId,
    required String details,
  }) async {
    await _auditLogs.add({
      'actorId': actorId,
      'action': action,
      'targetId': targetId,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Grant quiz access
  Future<void> grantQuizAccess({
    required String quizId,
    required String userId,
    required Map<String, bool> permissions,
    required String addedBy,
  }) async {
    await _quizAccess.doc('${quizId}_$userId').set({
      'quizId': quizId,
      'userId': userId,
      'permissions': permissions,
      'addedBy': addedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Ban user from a specific quiz
  Future<void> banUserFromQuiz({
    required String quizId,
    required String userId,
    required String reason,
    required String bannedBy,
  }) async {
    await FirebaseFirestore.instance.collection('quiz_bans').doc('${quizId}_$userId').set({
      'quizId': quizId,
      'userId': userId,
      'reason': reason,
      'bannedBy': bannedBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
