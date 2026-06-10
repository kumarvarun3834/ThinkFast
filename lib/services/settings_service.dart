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

  /// ✅ Fetch Feature Flags
  Future<Map<String, dynamic>?> getFeatureFlags() async {
    final doc = await _featureFlags.doc('production').get();
    return doc.data() as Map<String, dynamic>?;
  }

  /// ✅ Update App Setting
  Future<void> updateAppSetting(String key, dynamic value) async {
    await _settings.doc('app').set({
      key: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
