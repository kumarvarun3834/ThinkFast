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
}
