import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SettingsService {
  final CollectionReference _settings = FirebaseFirestore.instance.collection('settings');
  final CollectionReference _featureFlags = FirebaseFirestore.instance.collection('feature_flags');

  /// ✅ Fetch App Settings
  Future<Map<String, dynamic>?> getAppSettings() async {
    final doc = await _settings.doc('app').get();
    return doc.data() as Map<String, dynamic>?;
  }

  /// ✅ Stream App Settings
  Stream<Map<String, dynamic>?> streamAppSettings() {
    return _settings.doc('app').snapshots().map((doc) => doc.data() as Map<String, dynamic>?);
  }

  /// ✅ Fetch Feature Flags (Cached for session)
  Future<Map<String, dynamic>?> getFeatureFlags() async {
    final defaultFlags = {
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
      'user_action_logging': true,
      'management_features': true,
      'enable_quiz_creation_rate_limit': true,
      'quiz_creation_rate_limit_minutes': 5,
    };

    DocumentSnapshot doc;
    try {
      doc = await _featureFlags.doc('production').get().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Warning: Could not fetch feature flags ($e). Using defaults.");
      return defaultFlags;
    }

    if (!doc.exists) {
      try {
        await _featureFlags.doc('production').set({
          ...defaultFlags,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("Silent fail: Could not initialize feature flags document (Permission Denied)");
      }
      return defaultFlags;
    }

    final data = doc.data() as Map<String, dynamic>;

    // Check if any default flag is missing and update if necessary
    bool needsUpdate = false;
    defaultFlags.forEach((key, value) {
      if (!data.containsKey(key)) {
        data[key] = value;
        needsUpdate = true;
      }
    });

    if (needsUpdate) {
      try {
        await _featureFlags.doc('production').update(data);
      } catch (e) {
        debugPrint("Silent fail: Could not update missing feature flags (Permission Denied)");
      }
    }

    return data;
  }

  /// ✅ Stream Feature Flags for live updates
  Stream<Map<String, dynamic>?> streamFeatureFlags() {
    return _featureFlags.doc('production').snapshots().map((doc) => doc.data() as Map<String, dynamic>?);
  }

  /// ✅ Update a specific feature flag (Admin only)
  Future<void> updateFeatureFlag(String key, dynamic value) async {
    await _featureFlags.doc('production').set({
      key: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ Update App Setting
  Future<void> updateAppSetting(String key, dynamic value) async {
    await _settings.doc('app').set({
      key: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ Fetch Admin Settings (Template)
  /// Allow everyone to create the settings template if it doesn't exist, but doesn't add members
  Future<Map<String, dynamic>?> getAdminSettings() async {
    try {
      final doc = await _settings.doc('admin').get().timeout(const Duration(seconds: 5));
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
