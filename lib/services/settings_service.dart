import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'admin_service.dart';

class SettingsService {
  final CollectionReference _settings = FirebaseFirestore.instance.collection(
    'settings',
  );
  final CollectionReference _featureFlags = FirebaseFirestore.instance
      .collection('feature_flags');

  /// Flag to Document Mapping for granular permissions
  static const Map<String, String> _flagDocMap = {
    // Admin Management
    'admin_refresh_rate_limit_seconds': 'admin',
    // Moderation
    'enable_user_banning': 'moderation',
    // Quizzes
    'enable_quiz_creation_rate_limit': 'quizzes',
    'quiz_creation_rate_limit_minutes': 'quizzes',
    'enable_form_save_rate_limit': 'quizzes',
    'form_save_rate_limit_seconds': 'quizzes',
    'management_features': 'quizzes',
    // AI
    'enable_ai_quota_bypass': 'ai',
    'ai_daily_generation_limit': 'ai',
    // Logs
    'log': 'logs',
    'log_updates': 'logs',
    'log_deletes': 'logs',
    // Collaboration
    'enable_realtime_colab': 'collaboration',
  };

  /// ✅ Fetch App Settings
  Future<Map<String, dynamic>?> getAppSettings() async {
    final doc = await _settings.doc('app').get();
    return doc.data() as Map<String, dynamic>?;
  }

  /// ✅ Stream App Settings
  Stream<Map<String, dynamic>?> streamAppSettings() {
    return _settings
        .doc('app')
        .snapshots()
        .map((doc) => doc.data() as Map<String, dynamic>?);
  }

  /// ✅ Fetch Feature Flags (Cached for session)
  /// Aggregates flags from multiple granularly-permissioned documents.
  Future<Map<String, dynamic>?> getFeatureFlags() async {
    final Map<String, Map<String, dynamic>> docDefaults = {
      'public': {
        'enable_ai': true,
        'enable_import': true,
        'enable_login': true,
        'enable_register': true,
        'enable_create_quiz': true,
        'enable_edit_quiz': true,
        'enable_delete_quiz': true,
        'enable_take_quiz': true,
        'enable_profile_edit': true,
        'enable_analytics': true,
        'enable_export': true,
        'maintenance_mode': false,
        'random_quiz_generator': true,
      },
      'admin': {'admin_refresh_rate_limit_seconds': 30},
      'moderation': {'enable_user_banning': true},
      'ai': {
        'enable_ai_quota_bypass': false,
        'ai_daily_generation_limit': 10,
      },
      'quizzes': {
        'enable_quiz_creation_rate_limit': true,
        'quiz_creation_rate_limit_minutes': 5,
        'enable_form_save_rate_limit': true,
        'form_save_rate_limit_seconds': 30,
        'management_features': true,
      },
      'logs': {
        'log': true,
        'log_updates': true,
        'log_deletes': true,
      },
      'collaboration': {'enable_realtime_colab': true},
    };

    final Map<String, dynamic> allFlags = {};

    // Parallel fetch for all flag documents
    await Future.wait(docDefaults.keys.map((docId) async {
      try {
        final data = await _fetchAndSyncFlags(docId, docDefaults[docId]!);
        allFlags.addAll(data);
      } catch (e) {
        if (docId == 'public') {
          debugPrint("Critical: Public flags unavailable. Using defaults.");
        }
        allFlags.addAll(docDefaults[docId]!);
      }
    }));

    return allFlags;
  }

  /// Helper to fetch a specific flag document and ensure all default keys exist
  Future<Map<String, dynamic>> _fetchAndSyncFlags(
    String docId,
    Map<String, dynamic> defaults,
  ) async {
    DocumentSnapshot doc;
    try {
      doc = await _featureFlags
          .doc(docId)
          .get()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      rethrow;
    }

    if (!doc.exists) {
      try {
        await _featureFlags.doc(docId).set({
          ...defaults,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint(
          "Silent fail: Could not initialize '$docId' flags (Permission Denied)",
        );
      }
      return defaults;
    }

    final data = doc.data() as Map<String, dynamic>;
    bool needsUpdate = false;
    defaults.forEach((key, value) {
      if (!data.containsKey(key)) {
        data[key] = value;
        needsUpdate = true;
      }
    });

    if (needsUpdate) {
      try {
        await _featureFlags.doc(docId).update(data);
      } catch (e) {
        debugPrint(
          "Silent fail: Could not update missing flags in '$docId' (Permission Denied)",
        );
      }
    }
    return data;
  }

  /// ✅ Stream Feature Flags for live updates
  Stream<Map<String, dynamic>?> streamFeatureFlags() {
    return _featureFlags.snapshots().map((snapshot) {
      final Map<String, dynamic> combined = {};
      for (var doc in snapshot.docs) {
        combined.addAll(doc.data() as Map<String, dynamic>);
      }
      return combined.isNotEmpty ? combined : null;
    }).handleError((e) {
      // Fallback: If collection-wide listener fails, listen only to 'public'
      return _featureFlags.doc('public').snapshots().map(
        (doc) => doc.data() as Map<String, dynamic>?,
      );
    });
  }

  /// ✅ Update a specific feature flag (Routed by permission)
  Future<void> updateFeatureFlag(String key, dynamic value) async {
    final String docId = _flagDocMap[key] ?? 'public';

    await _featureFlags.doc(docId).set({
      key: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final String? adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId != null) {
      await AdminService().logAction(
        actorId: adminId,
        action: 'update_feature_flag',
        targetId: key,
        details: 'Set $key to $value',
        category: 'admin',
      );
    }
  }

  /// ✅ Update App Setting
  Future<void> updateAppSetting(String key, dynamic value) async {
    await _settings.doc('app').set({
      key: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final String? adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId != null) {
      await AdminService().logAction(
        actorId: adminId,
        action: 'update_app_setting',
        targetId: key,
        details: 'Set app setting $key to $value',
        category: 'admin',
      );
    }
  }

  /// ✅ AI Quota Management (Specific permission required in rules)
  Future<void> updateAiQuota(String key, dynamic value) async {
    await _settings.doc('ai').set({
      key: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final String? adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId != null) {
      await AdminService().logAction(
        actorId: adminId,
        action: 'update_ai_quota',
        targetId: key,
        details: 'Set AI quota $key to $value',
        category: 'admin',
      );
    }
  }

  /// ✅ Fetch Competitive Exam Configs
  Future<Map<String, dynamic>> getExamConfigs() async {
    final doc = await _settings.doc('exam_configs').get();
    if (!doc.exists) {
      return {
        'JEE Main': {'count': 90, 'time_limit': '180 min'},
        'NEET': {'count': 180, 'time_limit': '200 min'},
        'UPSC': {'count': 100, 'time_limit': '120 min'},
      };
    }
    return doc.data() as Map<String, dynamic>;
  }

  /// ✅ Fetch Admin Settings (Template)
  Future<Map<String, dynamic>?> getAdminSettings() async {
    try {
      final doc = await _settings
          .doc('admin')
          .get()
          .timeout(const Duration(seconds: 5));
      if (!doc.exists) {
        final defaultAdminSettings = {
          'min_level_to_manage_admins': 5,
          'super_admin_level': 10,
          'default_new_admin_level': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await _settings.doc('admin').set(defaultAdminSettings);
        return defaultAdminSettings;
      }
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      debugPrint("Warning: Could not fetch admin settings ($e)");
      return null;
    }
  }
}
