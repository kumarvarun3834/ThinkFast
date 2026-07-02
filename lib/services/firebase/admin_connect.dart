import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin_service.dart';
import '../quiz_service.dart';
import '../settings_service.dart';

/// 👑 Database Service for Platform-Wide Administrative Operations
class AdminDatabaseService {
  final AdminService _adminService = AdminService();
  final QuizService _quizService = QuizService();
  final SettingsService _settingsService = SettingsService();

  Future<void> _ensureAdminPermission(String userId, String permission) async {
    if (!await _adminService.hasPermission(userId, permission)) {
      throw Exception("Access Denied: Administrative permission '$permission' required.");
    }
  }

  /// 🔐 Helper to check required admin level for sensitive operations
  Future<void> _ensureAdminLevel(String userId, int requiredLevel) async {
    if (!await _adminService.hasRequiredLevel(userId, requiredLevel)) {
      throw Exception(
        "Access Denied: Administrative level $requiredLevel or higher required (and Admin Mode must be ON).",
      );
    }
  }

  // --- Admin & Experience Switching ---

  Future<bool> isRegisteredAdmin(String uid) =>
      _adminService.isRegisteredAdmin(uid);

  Future<bool> isAdmin(String uid) => _adminService.isAdmin(uid);

  Future<void> toggleAdminMode({required String uid, required bool enable}) =>
      _adminService.toggleAdminMode(uid: uid, enable: enable);

  Stream<List<Map<String, dynamic>>> getAllAdmins() => _adminService.getAllAdmins();

  Stream<List<Map<String, dynamic>>> getQuizBannedUsers(String quizId) => _adminService.getQuizBannedUsers(quizId);

  Stream<List<Map<String, dynamic>>> getDeletedQuizzes() => _adminService.getDeletedQuizzes();

  Future<void> addOrUpdateAdmin({
    required String targetUid,
    required List<String> permissions,
    required String actorUid,
    bool makeSuper = false,
  }) async {
    await _ensureAdminPermission(actorUid, 'manage_admins');
    return _adminService.addOrUpdateAdmin(
      targetUid: targetUid,
      selectedPermissions: permissions,
      actorUid: actorUid,
      makeSuper: makeSuper,
    );
  }

  Future<void> removeAdmin({
    required String targetUid,
    required String actorUid,
  }) async {
    await _ensureAdminPermission(actorUid, 'manage_admins');
    return _adminService.removeAdmin(targetUid: targetUid, actorUid: actorUid);
  }

  // --- Global User Moderation ---

  Future<void> banUser({
    required String userId,
    String? quizId,
    required String reason,
    required String adminId,
  }) async {
    if (quizId == null) {
      await _ensureAdminPermission(adminId, 'moderate_users');
    }
    return _adminService.banUser(
      userId: userId,
      quizId: quizId,
      reason: reason,
      adminId: adminId,
    );
  }

  Future<void> unbanUser({
    required String userId,
    String? quizId,
    required String adminId,
  }) async {
    return _adminService.unbanUser(
      userId: userId,
      quizId: quizId,
      adminId: adminId,
    );
  }

  Future<void> deleteUserAccount({required String targetUid, required String adminId}) async {
    await _ensureAdminPermission(adminId, 'moderate_users');
    return _adminService.deleteUserAccount(targetUid: targetUid, adminId: adminId);
  }

  Stream<List<Map<String, dynamic>>> getAllUsers(String adminId) => _adminService.getAllUsers();

  Future<Map<String, dynamic>?> getFullUserProfile(String uid, String adminId) async {
    await _ensureAdminPermission(adminId, 'moderate_users');
    return _adminService.getFullUserProfile(uid);
  }

  // --- Master Data & Analytics ---

  Stream<List<Map<String, dynamic>>> getUserQuizzesMaster(String userId, String adminId) {
    return _quizService.getUserQuizzesMaster(userId);
  }

  Stream<List<Map<String, dynamic>>> getUserAttempts(String userId, {bool includeDeleted = false}) {
    return _adminService.getUserAttempts(userId, includeDeleted: includeDeleted);
  }

  Future<List<Map<String, dynamic>>> fetchAllUsers() => _adminService.fetchAllUsers();

  Future<List<Map<String, dynamic>>> fetchAllAdmins() => _adminService.fetchAllAdmins();

  // --- System Auditing ---

  Future<List<Map<String, dynamic>>> fetchAllAuditLogs(String adminId) async {
    await _ensureAdminPermission(adminId, 'view_audit_logs');
    return _adminService.fetchAllAuditLogs();
  }

  Stream<List<Map<String, dynamic>>> streamAuditLogs() => _adminService.getAuditLogs();

  Future<Map<String, dynamic>?> getFeatureFlags() =>
      _settingsService.getFeatureFlags(isAdmin: true);

  // --- Database Maintenance ---

  Future<int> removeEmptyTags(String adminId) => _adminService.removeEmptyTags(adminId);
}
