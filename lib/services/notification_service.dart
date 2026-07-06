import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final CollectionReference _notifications = FirebaseFirestore.instance.collection('notifications');

  /// ✅ Send a notification to a user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    await _notifications.add({
      'userId': userId,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Stream notifications for a user
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _notifications
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// ✅ Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _notifications.doc(notificationId).update({'read': true});
  }

  /// ✅ Mark all as read
  Future<void> markAllAsRead(String userId) async {
    final batch = FirebaseFirestore.instance.batch();
    final unread = await _notifications
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    for (var doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// ✅ Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _notifications.doc(notificationId).delete();
  }

  /// ✅ Stream unread count
  Stream<int> getUnreadCount(String userId) {
    if (userId.isEmpty) return Stream.value(0);
    return _notifications
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// ✅ Broadcast a notification to all users (Simulated via global collection)
  Future<void> broadcastNotification({
    required String title,
    required String body,
    String? type,
    String? targetId,
  }) async {
    await FirebaseFirestore.instance.collection('global_notifications').add({
      'title': title,
      'body': body,
      'type': type,
      'targetId': targetId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Stream global notifications
  Stream<List<Map<String, dynamic>>> getGlobalNotifications() {
    return FirebaseFirestore.instance
        .collection('global_notifications')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              data['isGlobal'] = true;
              return data;
            }).toList());
  }
}
