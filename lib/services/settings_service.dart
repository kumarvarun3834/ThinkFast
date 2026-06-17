import 'package:cloud_firestore/cloud_firestore.dart';

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
    final doc = await _featureFlags.doc('production').get();
    if (!doc.exists) {
      // Return default flags if none exist
      final defaultFlags = {
        'enable_ai': true,
        'enable_login': true,
        'enable_register': true,
        'enable_create_quiz': true,
        'maintenance_mode': false,
        'random_quiz_generator': true,
        'user_action_logging': true,
        'management_features': true,
        'enable_quiz_creation_rate_limit': true,
        'quiz_creation_rate_limit_minutes': 5,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // Allow everyone to create the settings template if it doesn't exist
      await _featureFlags.doc('production').set(defaultFlags);
      return defaultFlags;
    }
    return doc.data() as Map<String, dynamic>?;
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
    final doc = await _settings.doc('admin').get();
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
  }
}
