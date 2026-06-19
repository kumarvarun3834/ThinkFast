import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final CollectionReference _admins = FirebaseFirestore.instance.collection('admins');
  final CollectionReference _reports = FirebaseFirestore.instance.collection('reports');
  final CollectionReference _auditLogs = FirebaseFirestore.instance.collection('audit_logs');
  final CollectionReference _quizAccess = FirebaseFirestore.instance.collection('quiz_access');
  final CollectionReference _bannedUsers = FirebaseFirestore.instance.collection('banned_users');
  final CollectionReference _responses = FirebaseFirestore.instance.collection('responses');

  // Safely check if a user is a registered admin
  Future<bool> isRegisteredAdmin(String uid) async {
    if (uid == 'y6IkZpvVBYZWvVzXwJTfcwC3EBu2') return true; // Super Admin Override
    final doc = await _admins.doc(uid).get();
    return doc.exists;
  }

  /// ✅ Check if user is admin AND has admin mode active
  /// Use this for UI visibility and secondary privilege checks
  Future<bool> isAdmin(String uid) async {
    if (uid == 'y6IkZpvVBYZWvVzXwJTfcwC3EBu2') return true; // Super Admin Override
    final doc = await _admins.doc(uid).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>;
    // MUST have toggle enabled AND be a registered admin
    return data['isAdminModeEnabled'] == true;
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
    if (uid == 'y6IkZpvVBYZWvVzXwJTfcwC3EBu2') return 10; // Super Admin Level
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

  /// ✅ Grant quiz management access (Collaborators)
  Future<void> grantQuizManagementAccess({
    required String quizId,
    required String userId,
    required Map<String, bool> permissions,
    required String addedBy,
  }) async {
    // Only App Admin or Quiz Owner can add managers
    final bool isAppAdmin = await isAdmin(addedBy);
    final quizDoc = await FirebaseFirestore.instance.collection('quizzes').doc(quizId).get();
    final bool isOwner = quizDoc.exists && quizDoc.data()?['creatorId'] == addedBy;

    if (!isAppAdmin && !isOwner) {
      throw Exception("Unauthorized: Only the Quiz Owner or an App Admin can manage collaborators.");
    }

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
      action: 'grant_management_access',
      targetId: quizId,
      details: 'Granted manager access to $userId with perms: $permissions',
      category: 'quiz_management',
    );
  }

  /// ✅ Add specific participant to a restricted quiz
  Future<void> addParticipant({
    required String quizId,
    required String userId,
    required String addedBy,
  }) async {
    await _quizAccess.doc('${quizId}_$userId').set({
      'quizId': quizId,
      'userId': userId,
      'addedBy': addedBy,
      'role': 'participant',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await logAction(
      actorId: addedBy,
      action: 'add_participant',
      targetId: quizId,
      details: 'Added participant $userId to quiz',
      category: 'quiz_management',
    );
  }

  /// ✅ Ban a user from a specific quiz or globally
  Future<void> banUser({
    required String userId,
    String? quizId,
    required String reason,
    required String adminId,
  }) async {
    if (quizId == null) {
      // Global Ban: Requires App Admin
      if (!await isAdmin(adminId)) {
        throw Exception("Unauthorized: Only App Admins can perform global bans.");
      }
    } else {
      // Quiz Ban: Requires App Admin OR Quiz Manager with 'canModerate'
      if (!await canManageQuiz(quizId, adminId, permission: 'canModerate')) {
        throw Exception("Unauthorized: You do not have moderation rights for this quiz.");
      }
    }

    final String banId = quizId != null ? '${quizId}_$userId' : 'global_$userId';
    await _bannedUsers.doc(banId).set({
      'userId': userId,
      'quizId': quizId, // null means global
      'reason': reason,
      'bannedBy': adminId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await logAction(
      actorId: adminId,
      action: 'ban_user',
      targetId: userId,
      details: 'Banned from ${quizId ?? "Global"}. Reason: $reason',
      category: 'moderation',
    );
  }

  /// ✅ Check if admin has enough level for an action
  Future<bool> hasRequiredLevel(String uid, int requiredLevel) async {
    // Requires active admin mode to use elevated levels
    if (!await isAdmin(uid)) return false;
    final level = await getAdminLevel(uid);
    return level >= requiredLevel;
  }

  /// ✅ Unban user
  Future<void> unbanUser({
    required String userId,
    String? quizId,
    required String adminId,
  }) async {
    if (quizId == null) {
      if (!await isAdmin(adminId)) {
        throw Exception("Unauthorized: Only App Admins can perform global unbans.");
      }
    } else {
      if (!await canManageQuiz(quizId, adminId, permission: 'canModerate')) {
        throw Exception("Unauthorized: You do not have moderation rights for this quiz.");
      }
    }

    final String banId = quizId != null ? '${quizId}_$userId' : 'global_$userId';
    await _bannedUsers.doc(banId).delete();

    await logAction(
      actorId: adminId,
      action: 'unban_user',
      targetId: userId,
      details: 'Unbanned from ${quizId ?? "Global"}',
      category: 'moderation',
    );
  }

  /// ✅ Check if user is banned
  Future<bool> isUserBanned(String userId, {String? quizId}) async {
    // Check global ban first
    final globalBan = await _bannedUsers.doc('global_$userId').get();
    if (globalBan.exists) return true;

    // Check quiz-specific ban
    if (quizId != null) {
      final quizBan = await _bannedUsers.doc('${quizId}_$userId').get();
      return quizBan.exists;
    }
    return false;
  }

  /// ✅ Soft delete a response (shows "Deleted by Admin" to user)
  Future<void> softDeleteResponse({
    required String responseId,
    required String quizId,
    required String adminId,
    required String reason,
  }) async {
    // Requires App Admin OR Quiz Manager with 'canModerate'
    if (!await canManageQuiz(quizId, adminId, permission: 'canModerate')) {
      throw Exception("Unauthorized: You do not have moderation rights for this quiz.");
    }

    await _responses.doc(responseId).update({
      'isDeleted': true,
      'deletedBy': adminId,
      'deleteReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await logAction(
      actorId: adminId,
      action: 'soft_delete_response',
      targetId: responseId,
      details: 'Reason: $reason',
      category: 'moderation',
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

  /// ✅ Master control: Force delete or update any quiz (App Admin only)
  Future<void> masterQuizControl({
    required String quizId,
    required Map<String, dynamic> updates,
    required String adminId,
  }) async {
    final bool isAppAdmin = await isAdmin(adminId);
    if (!isAppAdmin) throw Exception("Unauthorized: App Admin privileges required.");

    await FirebaseFirestore.instance.collection('quizzes').doc(quizId).update(updates);
    
    await logAction(
      actorId: adminId,
      action: 'master_control_update',
      targetId: quizId,
      details: 'App Admin performed master update: ${updates.keys.toList()}',
      category: 'admin_master',
    );
  }

  /// ✅ Check if user has specific management permission for a quiz
  /// Returns true if user is the Quiz Owner, an App Admin, or a Manager with the right permission.
  Future<bool> canManageQuiz(String quizId, String userId, {String? permission}) async {
    // 1. App Admin has global access
    if (await isAdmin(userId)) return true;

    // 2. Check if user is the owner
    final quizDoc = await FirebaseFirestore.instance.collection('quizzes').doc(quizId).get();
    if (quizDoc.exists && quizDoc.data()?['creatorId'] == userId) return true;

    // 3. Check if user is a manager with specific permission
    final accessDoc = await _quizAccess.doc('${quizId}_$userId').get();
    if (accessDoc.exists) {
      final data = accessDoc.data() as Map<String, dynamic>;
      if (data['role'] == 'manager') {
        if (permission == null) return true; // Just checking for general manager role
        final perms = data['permissions'] as Map<String, dynamic>? ?? {};
        return perms[permission] == true;
      }
    }

    return false;
  }

  /// ✅ Remove management access
  Future<void> removeQuizManagementAccess({
    required String quizId,
    required String userId,
    required String removedBy,
  }) async {
    // Only App Admin or Quiz Owner can remove managers
    if (!await canManageQuiz(quizId, removedBy)) {
      throw Exception("Unauthorized: Insufficient permissions to remove collaborators.");
    }

    await _quizAccess.doc('${quizId}_$userId').delete();

    await logAction(
      actorId: removedBy,
      action: 'remove_management_access',
      targetId: quizId,
      details: 'Removed manager access for $userId',
      category: 'quiz_management',
    );
  }

  /// ✅ Get all managers for a quiz
  Stream<List<Map<String, dynamic>>> getQuizManagers(String quizId) {
    return _quizAccess
        .where('quizId', isEqualTo: quizId)
        .where('role', isEqualTo: 'manager')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
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
