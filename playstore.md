# Play Store Compliance Status - ThinkFast

This document tracks the current alignment of ThinkFast with Google Play Store policies.

## ✅ Rules the App Follows

### 1. User Security & Authentication

* **Brute-Force Protection**: Implements IP-based login rate limiting. After 5 failed attempts, the
  IP is flagged and blocked for 1 hour.
* **Secure Authentication**: Uses Firebase Auth for industry-standard secure sign-in and password
  handling.
* **Verification Mandatory**: Restricts core features (taking/creating quizzes) to verified users
  only, reducing spam and bot activity.

### 2. Data Integrity & Cleanup

* **Automated Purging**: Automatically deletes unverified accounts after 7 days, ensuring the user
  database remains clean and compliant with "data minimization" principles.
* **Secure Data Storage**: Uses Firebase Firestore with granular security rules to prevent
  unauthorized access to private data.

### 3. Moderation Infrastructure (UGC)

* **Manager/Admin Controls**: Robust system for moderators to soft-delete inappropriate responses
  and ban users from specific quizzes.
* **Global Moderation**: Centralized Admin Panel for system-wide user banning and feature control.
* **Soft Deletion**: Content is "trashed" for 7 days before permanent removal, allowing for audit
  and recovery.
* **Reporting Mechanism**: Users can report offensive quizzes or specific questions. Reports are
  logged for administrative review, ensuring compliance with UGC policies.

### 4. AI Guardrails

* **Quota Management**: Daily limits on AI quiz generation to prevent resource abuse.
* **Safety Prompts**: AI generation uses structured system prompts to ensure professional and
  relevant content.
* **Reliability**: Triple-model fallback strategy ensures the service remains available and
  responsive.

### 5. Transparency

* **Feature Flagging**: Administrators can disable entire systems (AI, Imports, Registrations)
  instantly if vulnerabilities or issues arise.

### 6. Target Audience & Children’s Policy

* **Opt-in Data Collection**: The app uses an explicit "Opt-in for AI Analysis" flow. Sensitive data
  like Age and Grade are only collected if the user explicitly consents, ensuring a COPPA-compliant
  restricted mode for those who choose to remain anonymous.
* **Purpose-Driven Collection**: Collected data is strictly used for personalizing the learning
  experience via AI quiz generation.

### 8. Data Safety Disclosures
*   **Transparency**: A comprehensive map of all data collected (Personal Info, App Activity, and Security identifiers) has been documented, matching the requirements of the Play Console Data Safety form.

---

## ❌ Rules NOT Following (Required for Launch)

### 1. In-App Account Deletion (CRITICAL)
*   **Issue**: Google requires users to be able to delete their account and all associated data from within the app if they can create one.
*   **Status**: Currently, only admins can delete user accounts. Users lack a "Delete My Account" button in the Profile screen. (Added to tracker for next sprint).

### 2. Target Audience - Student Data
*   **Issue**: Since the app targets students (collecting Grade/Age), it must meet additional safety requirements if the target audience includes children under 13.
*   **Status**: Need to finalize "Parental Consent" flows if the age group is below 13 in certain regions.

---

## 📋 Play Store Data Safety Form (Breakdown)

Use the following information to fill out the Data Safety section in the Google Play Console:

### Data Collection & Purpose
| Data Type | Specific Data | Purpose |
| :--- | :--- | :--- |
| **Personal Info** | Name, Email Address | Account Management, App Functionality |
| **Personal Info** | Age, Education/Grade | App Functionality (AI Personalization) |
| **User Identifiers** | User ID (UID) | Account Management, Analytics |
| **App Activity** | App Interactions (Quiz attempts, Results) | App Functionality, Analytics |
| **App Activity** | In-app Search History | App Functionality |
| **App Activity** | User-generated Content (Created Quizzes) | App Functionality |
| **Security/Diagnostics** | IP Address | Security (Brute-force protection), Fraud Prevention |
| **Security/Diagnostics** | Audit Logs, Action Logs | Security, Compliance, Diagnostics |

### Data Handling Practices
*   **Data Encrypted in Transit**: All data is transferred over a secure, encrypted HTTPS connection.
*   **Data Sharing**: No user data is shared with third-party companies or advertisers.
*   **Data Deletion**: 
    *   Unverified accounts are automatically purged after 7 days.
    *   Quiz responses can be soft-deleted by users/managers.
    *   *Note: Self-service account deletion is currently a backlog item.*



