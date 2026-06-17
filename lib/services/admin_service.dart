import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final CollectionReference _admins = FirebaseFirestore.instance.collection('admins');
  final CollectionReference _reports = FirebaseFirestore.instance.collection('reports');
  final CollectionReference _auditLogs = FirebaseFirestore.instance.collection('audit_logs');
  final CollectionReference _quizAccess = FirebaseFirestore.instance.collection('quiz_access');

  /// ✅ Check if user is registered as an admin (base authority)
  Future<bool> isRegisteredAdmin(String uid) async {
    final doc = await _admins.doc(uid).get();
    return doc.exists;
  }

  /// ✅ Check if user is admin AND has admin mode active
  /// Use this for UI visibility and secondary privilege checks
  Future<bool> isAdmin(String uid) async {
    final doc = await _admins.doc(uid).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>;
    return data['isAdminModeEnabled'] ?? true; // Active by default
  }

  /// ✅ Toggle Admin Mode (Switch between normal user and admin experience)
  Future<void> toggleAdminMode({required String uid, required bool enable}) async {
    final exists = await isRegisteredAdmin(uid);
    if (!exists) throw Exception("Unauthorized: User is not a registered admin.");

    await _admins.doc(uid).update({
      'isAdminModeEnabled': enable,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await logAction(
      actorId: uid,
      action: 'toggle_admin_mode',
      targetId: uid,
      details: 'Admin mode set to: $enable',
      category: 'admin',
    );
  }

  /// ✅ Get admin level
  Future<int> getAdminLevel(String uid) async {
    final doc = await _admins.doc(uid).get();
    if (!doc.exists) return 0;
    final data = doc.data() as Map<String, dynamic>;
    return data['level'] ?? 1; // Default to level 1 if not specified
  }

  /// ✅ Add or Update Admin (Level system constraints)
  /// Higher level can remove or update lower level
  Future<void> addOrUpdateAdmin({
    required String targetUid,
    required int level,
    required String actorUid,
  }) async {
    final actorLevel = await getAdminLevel(actorUid);
    final targetCurrentLevel = await getAdminLevel(targetUid);

    // Constraint: Only higher level admins can add or update lower level admins
    if (actorLevel > targetCurrentLevel && actorLevel > level) {
      await _admins.doc(targetUid).set({
        'level': level,
        'addedBy': actorUid,
        'isAdminModeEnabled': true, // Default to active for new admins
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await logAction(
        actorId: actorUid,
        action: targetCurrentLevel == 0 ? 'add_admin' : 'update_admin_level',
        targetId: targetUid,
        details: 'Target: $targetUid, Level set to: $level',
        category: 'admin',
      );
    } else {
      throw Exception('Unauthorized: Higher admin level required to perform this action.');
    }
  }

  /// ✅ Remove Admin (Level system constraints)
  Future<void> removeAdmin({
    required String targetUid,
    required String actorUid,
  }) async {
    final actorLevel = await getAdminLevel(actorUid);
    final targetLevel = await getAdminLevel(targetUid);

    // Constraint: Only higher level admins can remove lower level admins
    if (actorLevel > targetLevel) {
      await _admins.doc(targetUid).delete();

      await logAction(
        actorId: actorUid,
        action: 'remove_admin',
        targetId: targetUid,
        details: 'Removed admin: $targetUid (was level $targetLevel)',
        category: 'admin',
      );
    } else {
      throw Exception('Unauthorized: Higher admin level required to remove this admin.');
    }
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

  /// ✅ Create Audit Log (Server-wide operation log)
  Future<void> logAction({
    required String actorId,
    required String action,
    required String targetId,
    required String details,
    String category = 'general',
  }) async {
    await _auditLogs.add({
      'actorId': actorId,
      'action': action,
      'targetId': targetId,
      'details': details,
      'category': category,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Grant quiz management access
  Future<void> grantQuizManagementAccess({
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
      'role': 'manager',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await logAction(
      actorId: addedBy,
      action: 'grant_access',
      targetId: quizId,
      details: 'Granted manager access to $userId',
      category: 'admin',
    );
  }

  /// ✅ Remove management access
  Future<void> removeQuizManagementAccess({
    required String quizId,
    required String userId,
    required String removedBy,
  }) async {
    await _quizAccess.doc('${quizId}_$userId').delete();

    await logAction(
      actorId: removedBy,
      action: 'remove_access',
      targetId: quizId,
      details: 'Removed manager access for $userId',
      category: 'admin',
    );
  }

  /// ✅ Member can quit quiz management
  Future<void> quitQuizManagement({
    required String quizId,
    required String userId,
  }) async {
    await _quizAccess.doc('${quizId}_$userId').delete();

    await logAction(
      actorId: userId,
      action: 'quit_management',
      targetId: quizId,
      details: 'User voluntarily left quiz management',
      category: 'admin',
    );
  }

  /// ✅ Master control: Get all quizzes (Admin only)
  Stream<List<Map<String, dynamic>>> getAllQuizzesMaster() {
    return FirebaseFirestore.instance.collection('quizzes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// ✅ Master control: Force delete or update any quiz (Admin only)
  Future<void> masterQuizControl({
    required String quizId,
    required Map<String, dynamic> updates,
    required String adminId,
  }) async {
    await FirebaseFirestore.instance.collection('quizzes').doc(quizId).update(updates);
    
    await logAction(
      actorId: adminId,
      action: 'master_control_update',
      targetId: quizId,
      details: 'Admin performed master update: ${updates.keys.toList()}',
      category: 'admin',
    );
  }

  /// ✅ Get all managers for a quiz
  Stream<List<Map<String, dynamic>>> getQuizManagers(String quizId) {
    return _quizAccess
        .where('quizId', isEqualTo: quizId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }

  /// ✅ Check if user is manager with specific permission
  Future<bool> hasPermission(String quizId, String userId, String permission) async {
    final doc = await _quizAccess.doc('${quizId}_$userId').get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>;
    final perms = data['permissions'] as Map<String, dynamic>? ?? {};
    return perms[permission] == true;
  }

  /// ✅ Get all audit logs (Admin only)
  Stream<List<Map<String, dynamic>>> getAuditLogs() {
    return _auditLogs
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }
}
