import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxdart/rxdart.dart';
import 'package:thinkfast/services/notification_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

import '../widgets/quiz_widgets.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Map<String, dynamic>>> _getCombinedStream() {
    return Rx.combineLatest2<
      List<Map<String, dynamic>>,
      List<Map<String, dynamic>>,
      List<Map<String, dynamic>>
    >(
      _notificationService.getUserNotifications(_uid!),
      _notificationService.getGlobalNotifications(),
      (user, global) {
        final combined = [...user, ...global];
        combined.sort((a, b) {
          final tA =
              (a['createdAt'] as dynamic)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final tB =
              (b['createdAt'] as dynamic)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return tB.compareTo(tA);
        });
        return combined;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return Scaffold(
        backgroundColor: global.bgColor,
        appBar: AppBar(title: const Text("Notifications")),
        body: const Center(child: Text("Please login to see notifications")),
      );
    }

    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Notifications",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => _notificationService.markAllAsRead(_uid!),
            child: const Text("Mark all as read"),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getCombinedStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 64,
                    color: global.borderColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No notifications yet",
                    style: GoogleFonts.poppins(color: global.labelColor),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              final bool isRead = n['read'] ?? false;
              final bool isGlobal = n['isGlobal'] ?? false;

              return Dismissible(
                key: Key(n['id']),
                direction: isGlobal
                    ? DismissDirection.none
                    : DismissDirection.endToStart,
                onDismissed: isGlobal
                    ? null
                    : (direction) {
                        _notificationService.deleteNotification(n['id']);
                      },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: global.errorColor,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Card(
                  color: isRead
                      ? global.cardColor
                      : global.cardColor.withValues(alpha: 0.8),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isGlobal
                          ? Colors.orangeAccent.withValues(alpha: 0.5)
                          : (isRead
                                ? global.borderColor
                                : global.primaryAccent.withValues(alpha: 0.5)),
                    ),
                  ),
                  child: ListTile(
                    onTap: () {
                      if (!isRead && !isGlobal)
                        _notificationService.markAsRead(n['id']);
                      if (n['type'] == 'new_quiz' && n['targetId'] != null) {
                        Navigator.pushNamed(
                          context,
                          '/Quiz Details',
                          arguments: n['targetId'],
                        );
                      }
                    },
                    leading: Icon(
                      isGlobal
                          ? Icons.campaign_rounded
                          : Icons.notifications_rounded,
                      color: isGlobal
                          ? Colors.orangeAccent
                          : (isRead ? global.labelColor : global.primaryAccent),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            n['title'] ?? 'Notification',
                            style: GoogleFonts.poppins(
                              color: global.valueColor,
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isGlobal)
                          const StatusBadge(
                            text: "GLOBAL",
                            color: Colors.orangeAccent,
                            fontSize: 8,
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          n['body'] ?? '',
                          style: GoogleFonts.poppins(
                            color: global.labelColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTime(n['createdAt']),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: (!isRead && !isGlobal)
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: global.primaryAccent,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return "Just now";
    final DateTime date = (timestamp as dynamic).toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    return "${date.day}/${date.month}/${date.year}";
  }
}
