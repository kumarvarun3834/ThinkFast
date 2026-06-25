import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:thinkfast/utils/global.dart' as global;

import 'settings_service.dart';

class AdminService {
  final CollectionReference _admins = FirebaseFirestore.instance.collection(
    'admins',
  );
  final CollectionReference _reports = FirebaseFirestore.instance.collection(
    'reports',
  );
  final CollectionReference _auditLogs = FirebaseFirestore.instance.collection(
    'audit_logs',
  );
  final CollectionReference _quizAccess = FirebaseFirestore.instance.collection(
    'quiz_access',
  );
  final CollectionReference _bannedUsers = FirebaseFirestore.instance
      .collection('banned_users');
  final CollectionReference _responses = FirebaseFirestore.instance.collection(
    'responses',
  );
  final CollectionReference _quizAttempts = FirebaseFirestore.instance
      .collection('quiz_attempts');

  static const List<String> allPermissions = [
    'manage_admins',
    'moderate_users',
    'manage_all_quizzes',
    'view_audit_logs',
    'manage_app_settings',
    'bypass_ai_limits',
    'bypass_rate_limits',
    'manage_collaborators',
  ];

  // Safely check if a user is a registered admin
  Future<bool> isRegisteredAdmin(String uid) async {
    try {
      final doc = await _admins.doc(uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// ✅ Check if user is admin AND has admin mode active
  /// Use this for UI visibility and secondary privilege checks
  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _admins.doc(uid).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;

      // Cache admin level and permissions
      global.adminLevel = data['level'] ?? 1;
      global.adminPermissions = List<String>.from(data['permissions'] ?? []);

      // MUST have toggle enabled AND be a registered admin
      return data['isAdminModeEnabled'] == true;
    } catch (e) {
      // If we can't even check (e.g. permission denied), they are effectively not an admin
      return false;
    }
  }

  /// ✅ Toggle Admin Mode (Switch between normal user and admin experience)
  Future<void> toggleAdminMode({
    required String uid,
    required bool enable,
  }) async {
    final exists = await isRegisteredAdmin(uid);
    if (!exists)
      throw Exception("Unauthorized: User is not a registered admin.");

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

  /// ✅ Get admin permissions
  Future<List<String>> getAdminPermissions(String uid) async {
    final doc = await _admins.doc(uid).get();
    if (!doc.exists) return [];
    final data = doc.data() as Map<String, dynamic>;

    // Super User (Level 0) gets all roles
    if (data['level'] == 0) {
      return allPermissions;
    }

    return List<String>.from(data['permissions'] ?? []);
  }

  /// ✅ Check if admin has specific permission
  Future<bool> hasPermission(String uid, String permission) async {
    if (!await isAdmin(uid)) return false;

    final doc = await _admins.doc(uid).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>;

    // Level 0 is Super User: bypass all permission checks
    if (data['level'] == 0) return true;

    final permissions = List<String>.from(data['permissions'] ?? []);
    return permissions.contains(permission);
  }

  /// ✅ Add or Update Admin with selectable permissions
  Future<void> addOrUpdateAdmin({
    required String targetUid,
    required List<String> permissions,
    required String actorUid,
    bool makeSuper = false,
  }) async {
    // Only admins with 'manage_admins' permission can add/update admins
    if (!await hasPermission(actorUid, 'manage_admins')) {
      throw Exception(
        'Unauthorized: Permission "manage_admins" required.',
      );
    }

    final Map<String, dynamic> data = {
      'permissions': permissions,
      'addedBy': actorUid,
      'isAdminModeEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Integrity Check: Only the Super Admin (Level 0) can grant Level 0 or manage another Level 0
    final targetDoc = await _admins.doc(targetUid).get();
    final bool isTargetSuper = targetDoc.exists && (targetDoc.data() as Map)['level'] == 0;
    
    if (global.adminLevel != 0) {
      if (makeSuper || isTargetSuper) {
        throw Exception("Unauthorized: Only a Super Admin can manage Super Admin privileges.");
      }
    }

    // Only add 'level' field if it is 0 (Super Admin)
    if (makeSuper) {
      data['level'] = 0;
    } else if (!isTargetSuper) {
      // If updating a standard admin, ensure 'level' field is removed/not present
      data['level'] = FieldValue.delete();
    }

    await _admins.doc(targetUid).set(data, SetOptions(merge: true));

    await logAction(
      actorId: actorUid,
      action: 'update_admin_permissions',
      targetId: targetUid,
      details: 'Target: $targetUid, Permissions: $permissions, Super: $makeSuper',
      category: 'admin',
    );
  }

  /// ✅ Remove Admin
  Future<void> removeAdmin({
    required String targetUid,
    required String actorUid,
  }) async {
    if (!await hasPermission(actorUid, 'manage_admins')) {
      throw Exception(
        'Unauthorized: Permission "manage_admins" required.',
      );
    }

    // Integrity Check: Cannot remove Super Admin unless actor is Super Admin
    final targetDoc = await _admins.doc(targetUid).get();
    if (targetDoc.exists && (targetDoc.data() as Map)['level'] == 0 && global.adminLevel != 0) {
      throw Exception("Unauthorized: Only a Super Admin can remove another Super Admin.");
    }

    await _admins.doc(targetUid).delete();

    await logAction(
      actorId: actorUid,
      action: 'remove_admin',
      targetId: targetUid,
      details: 'Removed admin: $targetUid',
      category: 'admin',
    );
  }

  /// ✅ Bulk update admin permissions
  Future<void> bulkUpdateAdminPermissions({
    required List<String> targetUids,
    required String actorUid,
    List<String>? grantPermissions,
    List<String>? revokePermissions,
    List<String>? setPermissions,
    bool? makeSuper,
  }) async {
    if (!await hasPermission(actorUid, 'manage_admins')) {
      throw Exception('Unauthorized: Permission "manage_admins" required.');
    }

    final batch = FirebaseFirestore.instance.batch();

    for (var targetUid in targetUids) {
      final docRef = _admins.doc(targetUid);
      final doc = await docRef.get();

      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
        'addedBy': actorUid,
        'isAdminModeEnabled': true,
      };

      if (setPermissions != null) {
        updates['permissions'] = setPermissions;
      } else if (grantPermissions != null || revokePermissions != null) {
        List<String> currentPerms = [];
        if (doc.exists) {
          currentPerms = List<String>.from((doc.data() as Map)['permissions'] ?? []);
        }

        if (grantPermissions != null) {
          for (var p in grantPermissions) {
            if (!currentPerms.contains(p)) currentPerms.add(p);
          }
        }

        if (revokePermissions != null) {
          currentPerms.removeWhere((p) => revokePermissions.contains(p));
        }
        updates['permissions'] = currentPerms;
      }

      if (makeSuper != null) {
        if (global.adminLevel != 0) {
          throw Exception("Unauthorized: Only a Super Admin can manage Super Admin privileges.");
        }
        if (makeSuper) {
          updates['level'] = 0;
          updates['permissions'] = allPermissions;
        } else {
          updates['level'] = FieldValue.delete();
        }
      }

      batch.set(docRef, updates, SetOptions(merge: true));
    }

    await batch.commit();

    await logAction(
      actorId: actorUid,
      action: 'bulk_update_admins',
      targetId: 'multiple',
      details: 'Updated ${targetUids.length} admins. Action: grant=${grantPermissions}, revoke=${revokePermissions}, set=${setPermissions}',
      category: 'admin',
    );
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
    // Check if logging is enabled
    final flags =
        global.featureFlags ?? await SettingsService().getFeatureFlags();
    if (flags?['user_action_logging'] == false) return;

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
    // Only App Admin, Quiz Owner or manager with permission can add managers
    if (!await canManageQuiz(quizId, addedBy, permission: 'can_manage_collaborators')) {
      throw Exception(
        "Unauthorized: Only the Quiz Owner, an App Admin, or an authorized Collaborator can manage collaborators.",
      );
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
        throw Exception(
          "Unauthorized: Only App Admins can perform global bans.",
        );
      }
    } else {
      // Quiz Ban: Requires App Admin OR Quiz Manager with 'canModerate' or 'can_ban_users'
      final bool hasPerm = await canManageQuiz(quizId, adminId, permission: 'canModerate') ||
                           await canManageQuiz(quizId, adminId, permission: 'can_ban_users');
      if (!hasPerm) {
        throw Exception(
          "Unauthorized: You do not have moderation or ban rights for this quiz.",
        );
      }
    }

    final String banId = quizId != null
        ? '${quizId}_$userId'
        : 'global_$userId';
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
    final doc = await _admins.doc(uid).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>;
    
    // Level 0 is Super User (hardcoded field)
    if (data['level'] == 0) return true;

    // Standard admins don't have a level field, they operate on permissions
    // If a specific level (like 1 or 2) is required for sub-admin features, 
    // we treat standard admins as level 1.
    const standardLevel = 1;
    return standardLevel >= requiredLevel;
  }

  /// ✅ Unban user
  Future<void> unbanUser({
    required String userId,
    String? quizId,
    required String adminId,
  }) async {
    if (quizId == null) {
      if (!await isAdmin(adminId)) {
        throw Exception(
          "Unauthorized: Only App Admins can perform global unbans.",
        );
      }
    } else {
      final bool hasPerm = await canManageQuiz(quizId, adminId, permission: 'canModerate') ||
                           await canManageQuiz(quizId, adminId, permission: 'can_ban_users');
      if (!hasPerm) {
        throw Exception(
          "Unauthorized: You do not have moderation or ban rights for this quiz.",
        );
      }
    }

    final String banId = quizId != null
        ? '${quizId}_$userId'
        : 'global_$userId';
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

  /// ✅ Soft delete a response (shows "Deleted" in UI)
  Future<void> softDeleteResponse({
    required String responseId,
    required String quizId,
    required String actorId,
    required String reason,
  }) async {
    final responseDoc = await _responses.doc(responseId).get();
    if (!responseDoc.exists) throw Exception("Response not found.");
    final responseData = responseDoc.data() as Map<String, dynamic>;

    bool canDelete = false;
    String deletedByType = 'system';

    // 1. Quiz Owner check (Prioritize Permission over Admin Mode label)
    final quizDoc = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .get();
    if (quizDoc.exists && quizDoc.data()?['creatorId'] == actorId) {
      canDelete = true;
      deletedByType = 'owner';
    }
    // 2. Quiz Manager with 'canModerate' check
    else if (await hasQuizPermission(quizId, actorId, 'canModerate')) {
      canDelete = true;
      deletedByType = 'manager';
    }
    // 3. App Admin check (If not owner/manager, but in Admin Mode)
    else if (await isAdmin(actorId)) {
      canDelete = true;
      deletedByType = 'admin';
    }
    // 4. Candidate (User) check - deleting their own response
    else if (responseData['userId'] == actorId) {
      canDelete = true;
      deletedByType = 'user';
    }

    if (!canDelete) {
      throw Exception(
        "Unauthorized: You do not have permission to delete this response.",
      );
    }

    final batch = FirebaseFirestore.instance.batch();
    final Map<String, dynamic> updates = {
      'isDeleted': true,
      'deletedBy': actorId,
      'deletedByType': deletedByType,
      'deleteReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Synchronize soft delete across 2-way storage
    batch.update(_responses.doc(responseId), updates);
    batch.update(
      _quizAttempts.doc(quizId).collection('attempts').doc(responseId),
      updates,
    );

    await batch.commit();

    await logAction(
      actorId: actorId,
      action: 'soft_delete_response',
      targetId: responseId,
      details: 'Type: $deletedByType, Quiz: $quizId, Reason: $reason',
      category: 'moderation',
    );
  }

  /// ✅ Restore a soft-deleted response
  Future<void> restoreResponse({
    required String responseId,
    required String quizId,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final Map<String, dynamic> updates = {
      'isDeleted': false,
      'deletedBy': FieldValue.delete(),
      'deletedByType': FieldValue.delete(),
      'deleteReason': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Synchronize restoration across 2-way storage
    batch.update(_responses.doc(responseId), updates);
    batch.update(
      _quizAttempts.doc(quizId).collection('attempts').doc(responseId),
      updates,
    );

    await batch.commit();

    await logAction(
      actorId: FirebaseAuth.instance.currentUser!.uid,
      action: 'restore_response',
      targetId: responseId,
      details: 'Quiz: $quizId',
      category: 'moderation',
    );
  }

  /// ✅ Stream all banned users for a specific quiz
  Stream<List<Map<String, dynamic>>> getQuizBannedUsers(String quizId) {
    return _bannedUsers.where('quizId', isEqualTo: quizId).snapshots().asyncMap((
      snapshot,
    ) async {
      List<Map<String, dynamic>> results = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Fetch user profile to show name/email
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(data['userId'])
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          data['userName'] = userData['name'];
          data['userPhoto'] = userData['photoUrl'];
        }

        // Also fetch private email if available (Admin only usually, but let's see)
        final privateDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(data['userId'])
            .collection('private')
            .doc('details')
            .get();
        if (privateDoc.exists) {
          data['userEmail'] = privateDoc.data()?['email'];
        }

        results.add(data);
      }
      return results;
    });
  }

  /// ✅ Master control: Get all quizzes (Admin only)
  Stream<List<Map<String, dynamic>>> getAllQuizzesMaster() {
    return FirebaseFirestore.instance
        .collection('quizzes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// ✅ Master control: Get all soft-deleted quizzes (Admin only)
  Stream<List<Map<String, dynamic>>> getDeletedQuizzes() {
    return FirebaseFirestore.instance
        .collection('quizzes')
        .where('isDeleted', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// ✅ Master control: Force delete or update any quiz
  Future<void> masterQuizControl({
    required String quizId,
    required Map<String, dynamic> updates,
    required String adminId,
  }) async {
    if (!await hasPermission(adminId, 'manage_all_quizzes')) {
      throw Exception("Unauthorized: 'manage_all_quizzes' permission required.");
    }

    await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .update(updates);

    await logAction(
      actorId: adminId,
      action: 'master_control_update',
      targetId: quizId,
      details: 'App Admin performed master update: ${updates.keys.toList()}',
      category: 'admin_master',
    );
  }

  /// ✅ Get all quiz access records for a specific user (for local caching)
  Future<List<Map<String, dynamic>>> getUserAccessRecords(String userId) async {
    try {
      final snapshot = await _quizAccess.where('userId', isEqualTo: userId).get();
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  /// ✅ Check if user has specific management permission for a quiz
  /// Returns true if user is the Quiz Owner, an App Admin, or a Manager with the right permission.
  Future<bool> canManageQuiz(
    String quizId,
    String userId, {
    String? permission,
  }) async {
    // 1. App Admin has global access
    if (global.isAdmin && userId == FirebaseAuth.instance.currentUser?.uid) return true;
    if (await isAdmin(userId)) return true;

    // 2. Check Local Cache (Fastest)
    if (global.ownedQuizIds.contains(quizId)) return true;
    if (global.managedQuizzes.containsKey(quizId)) {
      if (permission == null) return true;
      final perms = global.managedQuizzes[quizId]!;
      if (perms[permission] == true) return true;
      
      // Permission Aliases
      if (permission == 'canModerate' && (perms['can_moderate'] == true || perms['canModerate'] == true)) return true;
      if (permission == 'can_update' && (perms['canUpdateData'] == true || perms['can_update'] == true)) return true;
      if (permission == 'can_ban_users' && perms['can_ban_users'] == true) return true;
      if (permission == 'can_manage_collaborators' && perms['can_manage_collaborators'] == true) return true;
    }

    try {
      // 3. Fallback: Check if user is the owner via Firestore
      final quizDoc = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(quizId)
          .get();
      if (quizDoc.exists && quizDoc.data()?['creatorId'] == userId) {
        // Update cache
        global.ownedQuizIds.add(quizId);
        return true;
      }

      // 4. Fallback: Check if user is a manager via Firestore
      final accessDoc = await _quizAccess.doc('${quizId}_$userId').get();
      if (accessDoc.exists) {
        final data = accessDoc.data() as Map<String, dynamic>;
        if (data['role'] == 'manager') {
          // Update cache
          global.managedQuizzes[quizId] = Map<String, dynamic>.from(data['permissions'] ?? {});
          
          if (permission == null) return true;
          final perms = data['permissions'] as Map<String, dynamic>? ?? {};
          if (perms[permission] == true) return true;

          // Permission Aliases
          if (permission == 'canModerate' && (perms['can_moderate'] == true || perms['canModerate'] == true)) return true;
          if (permission == 'can_update' && (perms['canUpdateData'] == true || perms['can_update'] == true)) return true;
          if (permission == 'can_ban_users' && perms['can_ban_users'] == true) return true;
          if (permission == 'can_manage_collaborators' && perms['can_manage_collaborators'] == true) return true;
          
          return false;
        }
      }
    } catch (e) {
      return false;
    }

    return false;
  }

  /// ✅ Check if user has specific management permission for a quiz (Internal check)
  Future<bool> hasQuizPermission(
    String quizId,
    String userId,
    String permission,
  ) async {
    final accessDoc = await _quizAccess.doc('${quizId}_$userId').get();
    if (accessDoc.exists) {
      final data = accessDoc.data() as Map<String, dynamic>;
      if (data['role'] == 'manager') {
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
    // Only App Admin, Quiz Owner or manager with permission can remove managers
    if (!await canManageQuiz(quizId, removedBy, permission: 'can_manage_collaborators')) {
      throw Exception(
        "Unauthorized: Insufficient permissions to remove collaborators.",
      );
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

  /// ✅ Get all managers for a quiz with profile data
  Stream<List<Map<String, dynamic>>> getQuizManagers(String quizId) {
    return _quizAccess
        .where('quizId', isEqualTo: quizId)
        .where('role', isEqualTo: 'manager')
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Future<Map<String, dynamic>>> futures = snapshot.docs.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;

        try {
          // Fetch user profile
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(data['userId'])
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            data['userName'] = userData['name'];
            data['userPhoto'] = userData['photoUrl'];
          }
        } catch (e) {
          debugPrint("Error fetching profile for manager ${data['userId']}: $e");
        }
        return data;
      }).toList();

      return await Future.wait(futures);
    });
  }

  /// ✅ Get all audit logs (Admin only)
  Stream<List<Map<String, dynamic>>> getAuditLogs() {
    return _auditLogs
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList(),
        );
  }

  /// ✅ Fetch full user profile including private details (Admin only)
  Future<Map<String, dynamic>?> getFullUserProfile(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;

      final privateDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('details')
          .get();
      if (privateDoc.exists) {
        data.addAll(privateDoc.data() as Map<String, dynamic>);
      }
      
      data['uid'] = uid;
      return data;
    } catch (e) {
      return null;
    }
  }

  /// ✅ Master control: Get all users (Admin only)
  Stream<List<Map<String, dynamic>>> getAllUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['uid'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// ✅ Master control: Delete User Firestore Data
  Future<void> deleteUserAccount({
    required String targetUid,
    required String adminId,
  }) async {
    if (!await hasPermission(adminId, 'moderate_users')) {
      throw Exception("Unauthorized: 'moderate_users' permission required.");
    }

    // Integrity Check: Cannot delete a Super Admin or even another admin without manage_admins
    final targetDoc = await _admins.doc(targetUid).get();
    if (targetDoc.exists) {
       if (!await hasPermission(adminId, 'manage_admins')) {
         throw Exception("Unauthorized: 'manage_admins' permission required to delete another admin.");
       }
       final bool isTargetSuper = (targetDoc.data() as Map)['level'] == 0;
       if (isTargetSuper && global.adminLevel != 0) {
         throw Exception("Unauthorized: Only a Super Admin can delete another Super Admin.");
       }
    }

    final batch = FirebaseFirestore.instance.batch();
    
    // 1. Delete user doc
    batch.delete(FirebaseFirestore.instance.collection('users').doc(targetUid));
    
    // 2. Delete private/protected details
    batch.delete(FirebaseFirestore.instance.collection('users').doc(targetUid).collection('private').doc('details'));
    batch.delete(FirebaseFirestore.instance.collection('users').doc(targetUid).collection('protected').doc('details'));
    
    // 3. Remove from admin list if present
    batch.delete(_admins.doc(targetUid));
    
    // 4. Remove all global bans
    batch.delete(_bannedUsers.doc('global_$targetUid'));

    await batch.commit();

    await logAction(
      actorId: adminId,
      action: 'delete_user_account',
      targetId: targetUid,
      details: 'Permanently removed user Firestore data and admin status.',
      category: 'admin_master',
    );
  }

  /// ✅ Get all admins with profile data (Stream)
  Stream<List<Map<String, dynamic>>> getAllAdmins() {
    return _admins.snapshots().asyncMap((snapshot) async {
      List<Map<String, dynamic>> admins = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;

        // Fetch user profile to show name/photo
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          data['name'] = userData['name'];
          data['photoUrl'] = userData['photoUrl'];
        }
        admins.add(data);
      }
      return admins;
    });
  }

  /// ✅ Fetch all admins once (Future)
  Future<List<Map<String, dynamic>>> fetchAllAdmins() async {
    final snapshot = await _admins.get();
    List<Map<String, dynamic>> admins = [];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      data['uid'] = doc.id;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(doc.id)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        data['name'] = userData['name'];
        data['photoUrl'] = userData['photoUrl'];
      }
      admins.add(data);
    }
    return admins;
  }

  /// ✅ Fetch all users once (Future)
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();
  }
}
