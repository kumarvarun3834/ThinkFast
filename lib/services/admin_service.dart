import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:thinkfast/utils/global.dart' as global;

import 'attempt_service.dart';
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
  final CollectionReference _leaderboards = FirebaseFirestore.instance
      .collection('leaderboards');

  static const List<String> allPermissions = [
    'manage_admins',
    'moderate_users',
    'manage_all_quizzes',
    'view_audit_logs',
    'manage_app_settings',
    'bypass_ai_quotas',
    'manage_collaborators',
    'manage_leaderboards',
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

      // Populate active permissions list - handles both legacy List and new Map formats
      final rawPerms = data['permissions'];
      if (rawPerms is Map) {
        global.adminPermissions = rawPerms.entries
            .where((e) => e.value == true)
            .map((e) => e.key.toString())
            .toList();
      } else if (rawPerms is List) {
        global.adminPermissions = List<String>.from(rawPerms);
      } else {
        global.adminPermissions = [];
      }

      // MUST have toggle enabled AND be a registered admin
      final bool activeAdmin = data['isAdminModeEnabled'] == true;
      global.isAdmin = activeAdmin;
      global.isRegisteredAdmin = true;
      return activeAdmin;
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
    if (!exists) {
      throw Exception("Unauthorized: User is not a registered admin.");
    }

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
  Future<Map<String, bool>> getAdminPermissions(String uid) async {
    final doc = await _admins.doc(uid).get();
    if (!doc.exists) return {};
    final data = doc.data() as Map<String, dynamic>;

    // Super User (Level 0) gets all roles
    if (data['level'] == 0) {
      return {for (var p in allPermissions) p: true};
    }

    final rawPerms = data['permissions'];
    if (rawPerms is Map) {
      return Map<String, bool>.from(rawPerms);
    } else if (rawPerms is List) {
      final List<String> list = List<String>.from(rawPerms);
      return {for (var p in allPermissions) p: list.contains(p)};
    }

    return {};
  }

  /// ✅ Check if admin has specific permission
  Future<bool> hasPermission(String uid, String permission) async {
    if (!await isAdmin(uid)) return false;

    final doc = await _admins.doc(uid).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>;

    // Level 0 is Super User: bypass all permission checks
    if (data['level'] == 0) return true;

    final rawPerms = data['permissions'];
    if (rawPerms is Map) {
      return rawPerms[permission] == true;
    } else if (rawPerms is List) {
      return (rawPerms).contains(permission);
    }

    return false;
  }

  /// ✅ Add or Update Admin with selectable permissions
  Future<void> addOrUpdateAdmin({
    required String targetUid,
    required List<String> selectedPermissions,
    required String actorUid,
    bool makeSuper = false,
  }) async {
    // Only admins with 'manage_admins' permission can add/update admins
    if (!await hasPermission(actorUid, 'manage_admins')) {
      throw Exception('Unauthorized: Permission "manage_admins" required.');
    }

    // Convert List to Map (permissionKey: bool)
    final Map<String, bool> permissionsMap = {
      for (var p in allPermissions) p: selectedPermissions.contains(p),
    };

    final Map<String, dynamic> data = {
      'permissions': permissionsMap,
      'addedBy': actorUid,
      'isAdminModeEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Integrity Check: Only the Super Admin (Level 0) can grant Level 0 or manage another Level 0
    final targetDoc = await _admins.doc(targetUid).get();
    final targetData = targetDoc.data() as Map<String, dynamic>?;
    final bool isTargetSuper = targetDoc.exists && targetData?['level'] == 0;

    if (global.adminLevel != 0) {
      if (makeSuper || isTargetSuper) {
        throw Exception(
          "Unauthorized: Only a Super Admin can manage Super Admin privileges.",
        );
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
      details:
          'Target: $targetUid, Permissions: $selectedPermissions, Super: $makeSuper',
      category: 'admin',
    );
  }

  /// ✅ Remove Admin
  Future<void> removeAdmin({
    required String targetUid,
    required String actorUid,
  }) async {
    if (!await hasPermission(actorUid, 'manage_admins')) {
      throw Exception('Unauthorized: Permission "manage_admins" required.');
    }

    // Integrity Check: Cannot remove Super Admin unless actor is Super Admin
    final targetDoc = await _admins.doc(targetUid).get();
    final targetData = targetDoc.data() as Map<String, dynamic>?;
    if (targetDoc.exists &&
        targetData?['level'] == 0 &&
        global.adminLevel != 0) {
      throw Exception(
        "Unauthorized: Only a Super Admin can remove another Super Admin.",
      );
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
        updates['permissions'] = {
          for (var p in allPermissions) p: setPermissions.contains(p),
        };
      } else if (grantPermissions != null || revokePermissions != null) {
        Map<String, bool> currentPerms = {};
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          currentPerms = Map<String, bool>.from(data?['permissions'] ?? {});
        }

        if (grantPermissions != null) {
          for (var p in grantPermissions) {
            currentPerms[p] = true;
          }
        }

        if (revokePermissions != null) {
          for (var p in revokePermissions) {
            currentPerms[p] = false;
          }
        }
        updates['permissions'] = currentPerms;
      }

      if (makeSuper != null) {
        if (global.adminLevel != 0) {
          throw Exception(
            "Unauthorized: Only a Super Admin can manage Super Admin privileges.",
          );
        }
        if (makeSuper) {
          updates['level'] = 0;
          updates['permissions'] = {for (var p in allPermissions) p: true};
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
      details:
          'Updated ${targetUids.length} admins. Action: grant=$grantPermissions, revoke=$revokePermissions, set=$setPermissions',
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
        global.featureFlags ??
        await SettingsService().getFeatureFlags(isAdmin: global.isAdmin);
    if (flags?['log'] == false) return;

    String actorName = "Unknown";
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(actorId)
          .get();
      if (userDoc.exists) {
        actorName = userDoc.data()?['name'] ?? "Unknown";
      }
    } catch (e) {
      debugPrint("Error fetching actor name for log: $e");
    }

    await _auditLogs.add({
      'actorId': actorId,
      'actorName': actorName,
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
    if (!await canManageQuiz(
      quizId,
      addedBy,
      permission: 'can_manage_collaborators',
    )) {
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
      final bool hasPerm =
          await canManageQuiz(quizId, adminId, permission: 'canModerate') ||
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
      final bool hasPerm =
          await canManageQuiz(quizId, adminId, permission: 'canModerate') ||
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
      throw Exception(
        "Unauthorized: 'manage_all_quizzes' permission required.",
      );
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
      final snapshot = await _quizAccess
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
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
    if (global.isAdmin && userId == FirebaseAuth.instance.currentUser?.uid)
      return true;
    if (await isAdmin(userId)) return true;

    // 2. Check Local Cache (Fastest)
    if (global.ownedQuizIds.contains(quizId)) return true;
    if (global.managedQuizzes.containsKey(quizId)) {
      if (permission == null) return true;
      final perms = global.managedQuizzes[quizId]!;
      if (perms[permission] == true) return true;

      // Permission Aliases
      if (permission == 'canModerate' &&
          (perms['can_moderate'] == true || perms['canModerate'] == true))
        return true;
      if (permission == 'can_update' &&
          (perms['canUpdateData'] == true || perms['can_update'] == true))
        return true;
      if (permission == 'can_ban_users' && perms['can_ban_users'] == true)
        return true;
      if (permission == 'can_manage_collaborators' &&
          perms['can_manage_collaborators'] == true)
        return true;
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
          global.managedQuizzes[quizId] = Map<String, dynamic>.from(
            data['permissions'] ?? {},
          );

          if (permission == null) return true;
          final perms = data['permissions'] as Map<String, dynamic>? ?? {};
          if (perms[permission] == true) return true;

          // Permission Aliases
          if (permission == 'canModerate' &&
              (perms['can_moderate'] == true || perms['canModerate'] == true))
            return true;
          if (permission == 'can_update' &&
              (perms['canUpdateData'] == true || perms['can_update'] == true))
            return true;
          if (permission == 'can_ban_users' && perms['can_ban_users'] == true)
            return true;
          if (permission == 'can_manage_collaborators' &&
              perms['can_manage_collaborators'] == true)
            return true;

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
    if (!await canManageQuiz(
      quizId,
      removedBy,
      permission: 'can_manage_collaborators',
    )) {
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

  /// ✅ Stream all managers for a quiz with profile data
  Stream<List<Map<String, dynamic>>> getQuizManagers(String quizId) {
    return _quizAccess
        .where('quizId', isEqualTo: quizId)
        .where('role', isEqualTo: 'manager')
        .snapshots()
        .asyncMap((snapshot) async {
          final List<Future<Map<String, dynamic>>> futures = snapshot.docs.map((
            doc,
          ) async {
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
              debugPrint(
                "Error fetching profile for manager ${data['userId']}: $e",
              );
            }
            return data;
          }).toList();

          return await Future.wait(futures);
        });
  }

  /// ✅ Stream all allowed participants for a quiz
  Stream<List<Map<String, dynamic>>> getQuizParticipants(String quizId) {
    return _quizAccess
        .where('quizId', isEqualTo: quizId)
        .where('role', isEqualTo: 'participant')
        .snapshots()
        .asyncMap((snapshot) async {
          final List<Future<Map<String, dynamic>>> futures = snapshot.docs.map((
            doc,
          ) async {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;

            try {
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
              debugPrint(
                "Error fetching profile for participant ${data['userId']}: $e",
              );
            }
            return data;
          }).toList();

          return await Future.wait(futures);
        });
  }

  /// ✅ Get all audit logs (Admin only) (Stream)
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

  /// ✅ Fetch all audit logs once (Future)
  Future<List<Map<String, dynamic>>> fetchAllAuditLogs() async {
    final snapshot = await _auditLogs
        .orderBy('timestamp', descending: true)
        .limit(200)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// ✅ Clear all audit logs (Master Admin)
  Future<void> clearAuditLogs() async {
    final snapshot = await _auditLogs.get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// ✅ Fetch full user profile including private and protected details (Admin only)
  Future<Map<String, dynamic>?> getFullUserProfile(String uid) async {
    final String? adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId != null) {
      await logAction(
        actorId: adminId,
        action: 'see_user_private',
        targetId: uid,
        details: 'Admin viewed full user profile including private data',
        category: 'moderation',
      );
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;

      // 1. Fetch Protected Details (Goals, Interests, etc.)
      final protectedDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('protected')
          .doc('details')
          .get();
      if (protectedDoc.exists) {
        data.addAll(protectedDoc.data() as Map<String, dynamic>);
      }

      // 2. Fetch Private Details (Email, Active Sessions, etc.)
      final privateDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('details')
          .get();
      if (privateDoc.exists) {
        data.addAll(privateDoc.data() as Map<String, dynamic>);
      }

      // 3. Real-time sync for stats
      final quizzes = await FirebaseFirestore.instance
          .collection('quizzes')
          .where('creatorId', isEqualTo: uid)
          .where('isDeleted', isEqualTo: false)
          .get();
      final currentQuizCount = quizzes.docs.length;

      final attempts = await FirebaseFirestore.instance
          .collection('responses')
          .where('userId', isEqualTo: uid)
          .get();
      final currentAttemptCount = attempts.docs
          .where((doc) => doc.data()['isDeleted'] != true)
          .length;
      final currentDeletedCount = attempts.docs
          .where((doc) => doc.data()['isDeleted'] == true)
          .length;

      // Update document if stats have changed
      if (data['quizCount'] != currentQuizCount ||
          data['attemptCount'] != currentAttemptCount ||
          data['deletedAttemptCount'] != currentDeletedCount) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'quizCount': currentQuizCount,
          'attemptCount': currentAttemptCount,
          'deletedAttemptCount': currentDeletedCount,
        });

        data['quizCount'] = currentQuizCount;
        data['attemptCount'] = currentAttemptCount;
        data['deletedAttemptCount'] = currentDeletedCount;
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
        throw Exception(
          "Unauthorized: 'manage_admins' permission required to delete another admin.",
        );
      }
      final data = targetDoc.data() as Map<String, dynamic>?;
      final bool isTargetSuper = (data?['level'] == 0);
      if (isTargetSuper && global.adminLevel != 0) {
        throw Exception(
          "Unauthorized: Only a Super Admin can delete another Super Admin.",
        );
      }
    }

    final batch = FirebaseFirestore.instance.batch();

    // 1. Delete user doc
    batch.delete(FirebaseFirestore.instance.collection('users').doc(targetUid));

    // 2. Delete private/protected details
    batch.delete(
      FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('private')
          .doc('details'),
    );
    batch.delete(
      FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('protected')
          .doc('details'),
    );

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

    final List<Future<Map<String, dynamic>>> futures = snapshot.docs.map((
      doc,
    ) async {
      final data = doc.data();
      data['uid'] = doc.id;

      // Proactive sync for list view
      if (!data.containsKey('quizCount') || data['quizCount'] == 0) {
        final quizzes = await FirebaseFirestore.instance
            .collection('quizzes')
            .where('creatorId', isEqualTo: doc.id)
            .where('isDeleted', isEqualTo: false)
            .get();
        data['quizCount'] = quizzes.docs.length;

        // Background update to Firestore to fix the record
        if (data['quizCount'] > 0) {
          FirebaseFirestore.instance.collection('users').doc(doc.id).update({
            'quizCount': data['quizCount'],
          });
        }
      }

      return data;
    }).toList();

    return await Future.wait(futures);
  }

  /// ✅ Remove all tags that are not linked to any quizzes (Admin only)
  Future<int> removeEmptyTags(String adminId) async {
    if (!await hasPermission(adminId, 'manage_app_settings')) {
      throw Exception(
        "Unauthorized: 'manage_app_settings' permission required.",
      );
    }

    final snapshot = await FirebaseFirestore.instance.collection('tags').get();
    int count = 0;
    final batch = FirebaseFirestore.instance.batch();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final List quizIds = data['quizIds'] as List? ?? [];
      if (quizIds.isEmpty) {
        batch.delete(doc.reference);
        count++;
      }
    }

    if (count > 0) await batch.commit();

    await logAction(
      actorId: adminId,
      action: 'remove_empty_tags',
      targetId: 'multiple',
      details: 'Cleaned up $count orphaned tags.',
      category: 'admin_master',
    );

    return count;
  }

  /// ✅ Get user attempts (Admin view)
  Stream<List<Map<String, dynamic>>> getUserAttempts(
    String userId, {
    bool includeDeleted = false,
  }) {
    return AttemptService().getUserAttempts(
      userId,
      includeDeleted: includeDeleted,
    );
  }

  // --- Leaderboard Management ---

  /// ✅ Create or Update a manual leaderboard
  Future<void> saveLeaderboard({
    required String adminId,
    String? leaderboardId,
    String? quizId, // Link to a specific quiz
    required String title,
    required String description,
    required List<Map<String, dynamic>> entries,
    bool isPublic = true,
  }) async {
    // Permission Check: 
    // 1. Global Admin with 'manage_leaderboards'
    // 2. Quiz Owner or Quiz Manager with 'can_moderate' (for quiz-specific boards)
    bool authorized = await hasPermission(adminId, 'manage_leaderboards');
    
    if (!authorized && quizId != null) {
      authorized = await canManageQuiz(quizId, adminId, permission: 'canModerate');
    }

    if (!authorized) {
      throw Exception("Unauthorized: Insufficient permissions to manage leaderboards.");
    }

    // Enforce Rules: Unique Users and Top 10 Only
    final Map<String, Map<String, dynamic>> uniqueEntries = {};
    for (var entry in entries) {
      final uid = entry['userId']?.toString() ?? "guest_${DateTime.now().microsecondsSinceEpoch}";
      if (!uniqueEntries.containsKey(uid)) {
        uniqueEntries[uid] = entry;
      }
    }

    final List<Map<String, dynamic>> finalEntries = uniqueEntries.values.toList();
    finalEntries.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
    
    final trimmedEntries = finalEntries.take(10).toList();

    final data = {
      'title': title,
      'description': description,
      'quizId': quizId,
      'entries': trimmedEntries,
      'isPublic': isPublic,
      'updatedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Use quizId as the document ID for the primary leaderboard to make fetching easier
    final String docId = leaderboardId ?? quizId ?? _leaderboards.doc().id;
    
    if (leaderboardId == null && quizId == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _leaderboards.add(data);
    } else {
      await _leaderboards.doc(docId).set(data, SetOptions(merge: true));
    }

    await logAction(
      actorId: adminId,
      action: 'save_leaderboard',
      targetId: leaderboardId ?? 'new',
      details: 'Admin saved manual leaderboard: $title',
      category: 'admin',
    );
  }

  /// ✅ Delete a leaderboard
  Future<void> deleteLeaderboard(String leaderboardId, String adminId) async {
    final doc = await _leaderboards.doc(leaderboardId).get();
    if (!doc.exists) return;
    
    final quizId = (doc.data() as Map?)?['quizId'];
    
    bool authorized = await hasPermission(adminId, 'manage_leaderboards');
    if (!authorized && quizId != null) {
      authorized = await canManageQuiz(quizId, adminId, permission: 'canModerate');
    }

    if (!authorized) {
      throw Exception("Unauthorized: Insufficient permissions to delete leaderboard.");
    }

    await _leaderboards.doc(leaderboardId).delete();

    await logAction(
      actorId: adminId,
      action: 'delete_leaderboard',
      targetId: leaderboardId,
      details: 'Admin deleted leaderboard',
      category: 'admin',
    );
  }

  /// ✅ Stream all leaderboards
  Stream<List<Map<String, dynamic>>> getLeaderboards({bool includePrivate = false, String? quizId}) {
    Query query = _leaderboards.orderBy('updatedAt', descending: true);
    if (!includePrivate) {
      query = query.where('isPublic', isEqualTo: true);
    }
    if (quizId != null) {
      query = query.where('quizId', isEqualTo: quizId);
    }
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  /// ✅ Stream all content reports
  Stream<List<Map<String, dynamic>>> getContentReports() {
    return FirebaseFirestore.instance
        .collection('content_reports')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// ✅ Update report status
  Future<void> updateReportStatus(String reportId, String status, String adminId) async {
    await FirebaseFirestore.instance
        .collection('content_reports')
        .doc(reportId)
        .update({
      'status': status,
      'resolvedBy': adminId,
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    await logAction(
      actorId: adminId,
      action: 'update_report_status',
      targetId: reportId,
      details: 'Report status updated to: $status',
      category: 'moderation',
    );
  }

  /// ✅ Helper: Get Potential Leaders (Top 10 First Attempts only, Excluding Admins)
  Future<List<Map<String, dynamic>>> getPotentialLeaders(String quizId) async {
    final snapshot = await _responses
        .where('quizId', isEqualTo: quizId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('timestamp', descending: false) // Earliest attempts first
        .get();

    final Map<String, Map<String, dynamic>> firstAttempts = {};
    
    // Efficient Exclusion: Fetch all admin UIDs first
    final adminSnapshot = await _admins.get();
    final Set<String> adminUids = adminSnapshot.docs.map((doc) => doc.id).toSet();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final uid = data['userId'];
      if (uid != null && !firstAttempts.containsKey(uid)) {
        // Exclusion Check: Is this user an admin?
        if (adminUids.contains(uid)) continue; // Skip admins

        // Fetch display name from users collection
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        data['name'] = userDoc.data()?['name'] ?? 'Anonymous';
        firstAttempts[uid] = data;
      }
    }

    final List<Map<String, dynamic>> sorted = firstAttempts.values.toList();
    // Sort by Score DESC, then Time ASC
    sorted.sort((a, b) {
      int scoreA = a['score'] ?? 0;
      int scoreB = b['score'] ?? 0;
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      
      final tA = (a['timestamp'] as dynamic)?.toDate() ?? DateTime.now();
      final tB = (b['timestamp'] as dynamic)?.toDate() ?? DateTime.now();
      return tA.compareTo(tB);
    });

    return sorted.take(10).toList().asMap().entries.map((e) {
      final idx = e.key;
      final val = e.value;
      return {
        'userId': val['userId'],
        'name': val['name'],
        'score': val['score'],
        'rank': idx + 1,
      };
    }).toList();
  }
}
