# Admin and Feature Configuration

This document outlines the structure for administrative roles and application feature flags used in the ThinkFast project.

## 1. Feature Flags
Feature flags are stored in the `feature_flags` collection and provide global control over application functionality.

### Primary Document
- **Path**: `feature_flags/production`
- **Purpose**: Centralized control for production features and rate limits.

| Field Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `enable_create_quiz` | `bool` | `true` | Allows regular users to create new quizzes. |
| `enable_ai` | `bool` | `true` | Enables AI-driven features (generation, etc.). |
| `enable_import` | `bool` | `false` | Enables JSON/URL import in the Quiz Editor. |
| `enable_login` | `bool` | `true` | Controls user sign-in availability. |
| `enable_register` | `bool` | `true` | Controls new user registration. |
| `maintenance_mode` | `bool` | `false` | Blocks app access for maintenance. |
| `random_quiz_generator` | `bool` | `true` | Enables random quiz selection features. |
| `user_action_logging` | `bool` | `true` | Enables server-side audit logging of actions. |
| `management_features` | `bool` | `true` | Enables admin management UI tools. |
| `enable_quiz_creation_rate_limit` | `bool` | `true` | Toggles the creation cooldown for users. |
| `quiz_creation_rate_limit_minutes` | `number` | `5` | Minutes required between quiz creations. |
| `updatedAt` | `timestamp` | - | Last modification time. |

---

## 2. Administrator Storage
Administrators are stored in the `admins` collection, indexed by their Firebase Auth **UID**.

### Admin Document Structure
- **Path**: `admins/{userId}`
- **Purpose**: Defines privileges and state for administrative users.

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `level` | `number` | Hierarchy level (e.g., 1=Standard, 10=Super Admin). Higher levels can manage lower levels. |
| `isAdminModeEnabled` | `bool` | Toggle for "Admin Mode" UI experience. If `false`, the user acts as a regular user. |
| `addedBy` | `string` | The UID of the admin who granted this user administrative rights. |
| `updatedAt` | `timestamp` | Last update to the admin status or mode. |

### Hierarchy Logic
- Only admins with a **higher level** can add, update, or remove another admin.
- Only admins with a **higher level** than the level being assigned can grant that specific level to a new admin.

---

## 3. Audit Logs
Every administrative action (adding admins, toggling modes, deleting quizzes) is recorded in the `audit_logs` collection.

- **Fields**: `actorId`, `action`, `targetId`, `details`, `category`, `timestamp`.
