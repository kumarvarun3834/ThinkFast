# Notification System Documentation & Test Plan

## 📋 Overview
The ThinkFast notification system handles two types of alerts:
1.  **Personal Notifications**: Score results, personal feedback, and account updates. Stored in the `notifications` collection keyed by `userId`.
2.  **Global Notifications**: System-wide broadcasts like new public quizzes or maintenance alerts. Stored in the `global_notifications` collection.

---

## 🛠️ Implementation Details
- **Service**: `lib/services/notification_service.dart`
- **UI**: `lib/screens/notification_screen.dart`
- **Merging Strategy**: Uses `rxdart` with `Rx.combineLatest2` to merge personal and global streams reactively.
- **Triggers**:
    - `AttemptService`: Sends personal result notification on quiz submission.
    - `QAdminDatabaseService`: Broadcasts global notification when a new public quiz is created.

---

## 🧪 Test Plan

### Test 1: Personal Result Notification
1.  Log in to the app.
2.  Open any quiz and complete it.
3.  Submit the quiz.
4.  **Expected Result**: A new notification should appear in the Notification Center (and the bell icon badge should increment) showing your score and percentage.

### Test 2: Global Quiz Broadcast
1.  Create a new quiz.
2.  Set its visibility to **Public**.
3.  Ensure it is **not restricted** and **not personal**.
4.  Save/Publish the quiz.
5.  **Expected Result**: A new "GLOBAL" notification should appear for **all users** (test with a different account if possible) with a campaign icon (📣).

### Test 3: "Mark as Read" Logic
1.  Open the Notification Screen.
2.  Identify an unread notification (marked with a blue dot and bold text).
3.  Tap on the notification.
4.  **Expected Result**: The blue dot should disappear, and the text should transition to normal weight. The unread count badge in the main screen should decrement.

### Test 4: Bulk Action
1.  Ensure you have multiple unread notifications.
2.  Tap "Mark all as read" in the AppBar.
3.  **Expected Result**: All notifications in the list should lose their "unread" status markers instantly.

### Test 5: Interactive Navigation
1.  Identify a notification for a "New Quiz Alert".
2.  Tap on it.
3.  **Expected Result**: The app should automatically navigate you to the **Quiz Details** screen for that specific quiz.

### Test 6: Deletion (Dismissible)
1.  Swipe a **Personal** notification from right to left.
2.  **Expected Result**: The notification should be removed from the list and deleted from Firestore.
3.  **Note**: Global notifications are not dismissible as they are system-wide.

---

## 🔒 Firestore Rules Verification
Ensure your `firestore.rules` includes:
```javascript
match /notifications/{notifId} {
  allow read, update: if isAuthenticated() && resource.data.get('userId', '') == request.auth.uid;
  allow create, delete: if isGlobalAdmin();
}
match /global_notifications/{notifId} {
  allow read: if isAuthenticated();
  allow create, update, delete: if isGlobalAdmin();
}
```
