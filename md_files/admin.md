# Admin and Feature Configuration

This document outlines the structure for administrative roles and application feature flags used in
the ThinkFast project.

## 1. Feature Flags

Feature flags are stored in the `feature_flags` collection and provide global control over
application functionality.

### Primary Document

- **Path**: `feature_flags/production`
- **Purpose**: Centralized control for production features and rate limits.

| Field Name                         | Type        | Default | Description                                    |
|:-----------------------------------|:------------|:--------|:-----------------------------------------------|
| `enable_create_quiz`               | `bool`      | `true`  | Allows regular users to create new quizzes.    |
| `enable_ai`                        | `bool`      | `true`  | Enables AI-driven features (generation, etc.). |
| `enable_import`                    | `bool`      | `false` | Enables JSON/URL import in the Quiz Editor.    |
| `enable_login`                     | `bool`      | `true`  | Controls user sign-in availability.            |
| `enable_register`                  | `bool`      | `true`  | Controls new user registration.                |
| `maintenance_mode`                 | `bool`      | `false` | Blocks app access for maintenance.             |
| `random_quiz_generator`            | `bool`      | `true`  | Enables random quiz selection features.        |
| `user_action_logging`              | `bool`      | `true`  | Enables server-side audit logging of actions.  |
| `management_features`              | `bool`      | `true`  | Enables admin management UI tools.             |
| `enable_quiz_creation_rate_limit`  | `bool`      | `true`  | Toggles the creation cooldown for users.       |
| `quiz_creation_rate_limit_minutes` | `number`    | `5`     | Minutes required between quiz creations.       |
| `admin_refresh_rate_limit_seconds` | `number`    | `30`    | Cooldown between manual data refreshes in UI.  |
| `updatedAt`                        | `timestamp` | -       | Last modification time.                        |

---

## 2. Administrator Storage

Administrators are stored in the `admins` collection, indexed by their Firebase Auth **UID**.

### Admin Document Structure

- **Path**: `admins/{userId}`
- **Purpose**: Defines specific privileges and state for administrative users.

| Field Name           | Type            | Description                                                                         |
|:---------------------|:----------------|:------------------------------------------------------------------------------------|
| `permissions`        | `array<string>` | List of specific keys defining what the admin can do.                               |
| `level`              | `number`        | Account hierarchy. `0` represents a **Super Admin** with full access.               |
| `isAdminModeEnabled` | `bool`          | Toggle for "Admin Mode" UI experience. If `false`, the user acts as a regular user. |
| `addedBy`            | `string`        | The UID of the admin who granted this user administrative rights.                   |
| `updatedAt`          | `timestamp`     | Last update to the admin status or permissions.                                     |

### Permission-Based System

Administrative powers are granted via discrete permission keys. **Note:** "Admin Mode" must be
toggled **ON** in the sidebar to activate these privileges.

| Permission Key         | Display Name           | Manageable Features                                                             |
|:-----------------------|:-----------------------|:--------------------------------------------------------------------------------|
| `manage_admins`        | Manage App Admins      | Can add, edit, or remove other App Admins and assign permissions.               |
| `moderate_users`       | Global User Moderation | Can issue global bans/unbans and moderate user-generated content.               |
| `manage_all_quizzes`   | Master Quiz Control    | Force update, lock, or delete any quiz on the platform regardless of ownership. |
| `view_audit_logs`      | View Audit Logs        | Full access to the system-wide activity audit trail.                            |
| `manage_app_settings`  | Manage App Settings    | Toggle Global Maintenance Mode and modify feature flags/rate limits.            |
| `bypass_ai_limits`     | Bypass AI Quotas       | Exempt from daily AI generation limits and cooldowns.                           |
| `bypass_rate_limits`   | Bypass Rate Limits     | Exempt from UI refresh and quiz creation cooldowns.                             |
| `manage_collaborators` | Manage Collaborators   | Add or remove managers for any quiz globally.                                   |

### Authorization Logic

- **Super Admin (`level: 0`)**: Automatically possesses all permissions and can manage other Super
  Admins.
- **Admin Mode Requirement**: To perform any administrative action, the user must have the relevant
  document in the `admins` collection AND have `isAdminModeEnabled` set to `true`.
- **Permission Check**: Features check for specific keys in the `permissions` array.
- **Bulk Updates**: Admins with `manage_admins` can perform collective updates (Grant/Revoke/Set) on
  multiple admin accounts simultaneously.

---

## 3. Audit Logs & Generation Logs

Critical system events are recorded in dedicated collections managed primarily by the backend.

- **Audit Logs**: Records staff actions (permissions, deletions). Fields: `actorId`, `actorName`, `action`, `targetId`, `category`, `timestamp`.
- **AI Generation Logs**: Tracks user generation metrics (model, latency, tokens). Managed by the backend to prevent client-side manipulation.

---

## 4. Platform Management & Security (v1.2)

### 4.1 AI Service Orchestration
The AI workflow is now centralized through the backend API (`PUT /api/quizzes/:quizId`).
- **Log Cleanup**: Backend automatically deletes corresponding generation logs when a quiz is updated.
- **Ownership Transfer**: Backend removes the AI flag to signify the quiz is now user-controlled. No secondary AI tags are attached, giving users full control.
- **Privacy Enforcement**: Admins can oversee the `optInAiAnalysis` status to ensure compliance.

### 4.2 Security Log Monitoring
A dedicated view in the Admin Panel provides visibility into `security_logs`:
- **IP Tracking**: Logs every failed login with its public IP.
- **Block Management**: View and manually override 1-hour automated IP bans.

### 4.3 Manual Leaderboard Management
The system supports **Manual Leaderboards** to ensure ranking high-integrity:
- **Permission**: Controlled by the `manage_leaderboards` key.
- **Scoping**: Allows creation of global boards or quiz-specific rankings.
- **Automation**: "Magic Wand" scans responses for earliest successful attempts.
- **Admin Direct Write**: Admins retain direct Firestore write access to bypass AI-related lockdowns for manual corrections.

### 4.4 Advanced Hierarchy Override
Admins can bypass the `/explanation` write-lock using the Admin SDK or direct console access to perform data corrections for user evaluates.
