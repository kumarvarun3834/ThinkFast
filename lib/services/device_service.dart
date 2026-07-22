import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _deviceIdKey = 'device_id';

  /// Get or Generate a unique Device ID for this installation
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      // Generate a random ID
      deviceId = _generateRandomId();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  String _generateRandomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      20, (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ));
  }

  /// Check if another device is currently active for this user
  Future<bool> checkConflict(String userId) async {
    final deviceId = await getDeviceId();
    final doc = await _db.collection('devices').doc(userId).get();
    
    if (doc.exists) {
      final activeId = doc.data()?['activeDeviceId'] as String?;
      return activeId != null && activeId != deviceId;
    }
    return false;
  }

  /// Update the active device ID in Firestore
  Future<void> updateActiveDevice(String userId) async {
    final deviceId = await getDeviceId();

    // 1. Update the master pointer for quick watching
    await _db.collection('devices').doc(userId).set({
      'activeDeviceId': deviceId,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Update the specific device document (requested path: devices/userid/deviceid)
    await _db
        .collection('devices')
        .doc(userId)
        .collection('active_device')
        .doc(deviceId)
        .set({
          'lastActive': FieldValue.serverTimestamp(),
          'deviceInfo': 'Mobile',
        }, SetOptions(merge: true));
  }

  /// ✅ Clear the active device ID in Firestore (on Logout)
  /// This method is called during the sign-out process.
  Future<void> clearActiveDevice(String userId) async {
    final deviceId = await getDeviceId();

    // 1. Remove the master pointer
    await _db.collection('devices').doc(userId).update({
      'activeDeviceId': FieldValue.delete(),
    });

    // 2. Remove the specific device document
    await _db
        .collection('devices')
        .doc(userId)
        .collection('active_device')
        .doc(deviceId)
        .delete();
  }

  /// Listen for changes in the active device ID
  Stream<String?> watchActiveDevice(String userId) {
    return _db.collection('devices').doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        return data?['activeDeviceId'] as String?;
      }
      return null;
    });
  }
}
