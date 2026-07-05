# Quiz-Level Administration (Collaborators)

This document defines the roles, data structures, and permissions for users managed at the specific
quiz level, referred to as **Quiz Admins** or **Collaborators**.

## 1. Overview

A Quiz Admin is a user who has been granted specific management rights over a single quiz by the *
*Quiz Owner** or an **App Admin**. These permissions are granular and tied to the specific `quizId`.

---

## 2. Data Storage

Quiz administration data is stored in the `quiz_access` collection.

### Document Path

- **Path**: `quiz_access/{quizId}_{userId}`
- **Purpose**: Maps a user to a quiz with a specific role and set of permissions.

### Document Fields

| Field         | Type        | Description                                        |
|:--------------|:------------|:---------------------------------------------------|
| `quizId`      | `string`    | The ID of the quiz being managed.                  |
| `userId`      | `string`    | The UID of the managed user.                       |
| `role`        | `string`    | The primary role (e.g., `manager`, `participant`). |
| `permissions` | `map`       | A map of boolean flags for granular actions.       |
| `addedBy`     | `string`    | The UID of the user who granted this access.       |
| `updatedAt`   | `timestamp` | Last update time.                                  |

---

## 3. Roles and Permissions

### 3.1 Primary Roles

- **Owner**: The creator of the quiz. Has implicit full control (all permissions) and bypasses session/lock checks for their own quiz.
- **Manager**: A collaborator with specific granted permissions.
- **Participant**: A user explicitly granted access to attempt a restricted or private quiz.

### 3.2 Granular Permissions (`permissions` map)

These flags control access to specific UI features and API operations:

| Flag Name                  | Purpose                                              |
|:---------------------------|:-----------------------------------------------------|
| `can_update`               | Edit quiz metadata, questions, and marking schemes.  |
| `can_delete`               | Perform a soft-delete of the quiz.                   |
| `can_publish`              | Change quiz visibility (Public, Private, Protected). |
| `can_view_results`         | View participant responses.                          |
| `can_view_answer_key`      | View the correct answers and solutions.              |
| `can_view_analytics`       | Access performance charts and detailed statistics.   |
| `can_export_data`          | Download attempt results in CSV/JSON formats.        |
| `canModerate`              | Soft-delete responses and ban users from this quiz.  |
| `can_manage_collaborators` | Add or remove other collaborators for this quiz.     |
| `can_ban_users`            | Specifically manage the ban list for this quiz.      |

> **Note on Naming:** There is currently a mix of snake_case (`can_update`) used in Firestore Rules
> and camelCase (`canModerate`) used in the Dart services. Both must be respected based on the context
> of the check.

This document defines the roles, data structures, and permissions for users managed at the specific
quiz level, referred to as **Quiz Admins** or **Collaborators**.

## 1. Overview

A Quiz Admin is a user who has been granted specific management rights over a single quiz by the *
*Quiz Owner** or an **App Admin**. These permissions are granular and tied to the specific `quizId`.

---

## 2. Data Storage

Quiz administration data is stored in the `quiz_access` collection.

### Document Path

- **Path**: `quiz_access/{quizId}_{userId}`
- **Purpose**: Maps a user to a quiz with a specific role and set of permissions.

### Document Fields

| Field         | Type        | Description                                        |
|:--------------|:------------|:---------------------------------------------------|
| `quizId`      | `string`    | The ID of the quiz being managed.                  |
| `userId`      | `string`    | The UID of the managed user.                       |
| `role`        | `string`    | The primary role (e.g., `manager`, `participant`). |
| `permissions` | `map`       | A map of boolean flags for granular actions.       |
| `addedBy`     | `string`    | The UID of the user who granted this access.       |
| `updatedAt`   | `timestamp` | Last update time.                                  |

---

## 3. Roles and Permissions

### 3.1 Primary Roles

- **Owner**: The creator of the quiz. Has implicit full control (all permissions) and bypasses session/lock checks for their own quiz.
- **Manager**: A collaborator with specific granted permissions.
- **Participant**: A user explicitly granted access to attempt a restricted or private quiz.

### 3.2 Granular Permissions (`permissions` map)

These flags control access to specific UI features and API operations:

| Flag Name                  | Purpose                                              |
|:---------------------------|:-----------------------------------------------------|
| `can_update`               | Edit quiz metadata, questions, and marking schemes.  |
| `can_delete`               | Perform a soft-delete of the quiz.                   |
| `can_publish`              | Change quiz visibility (Public, Private, Protected). |
| `can_view_results`         | View participant responses.                          |
| `can_view_answer_key`      | View the correct answers and solutions.              |
| `can_view_analytics`       | Access performance charts and detailed statistics.   |
| `can_export_data`          | Download attempt results in CSV/JSON formats.        |
| `canModerate`              | Soft-delete responses and ban users from this quiz.  |
| `can_manage_collaborators` | Add or remove other collaborators for this quiz.     |
| `can_ban_users`            | Specifically manage the ban list for this quiz.      |

> **Note on Naming:** There is currently a mix of snake_case (`can_update`) used in Firestore Rules
> and camelCase (`canModerate`) used in the Dart services. Both must be respected based on the context
> of the check.

---

## 4. Hierarchy & Management Rules

1. **Granting Access**: Only the **Quiz Owner** or an **App Admin** with the `manage_collaborators` permission can add a Manager to a quiz.
2. **App Admin Override**: Users with the global **Admin Mode** enabled bypass these checks and can
   manage any quiz on the platform.
3. **Conflict Resolution**: If a user is both a Manager and an App Admin, the global Admin
   privileges take precedence.
4. **Revocation**: Only the **Quiz Owner** or an **App Admin** can remove a Manager's access1. **Granting Access**: Only the **Quiz Owner** or an **App Admin** with the `manage_collaborators` permission can add a Manager to a quiz.
2. **App Admin Override**: Users with the global **Admin Mode** enabled bypass these checks and can
   manage any quiz on the platform.
3. **Conflict Resolution**: If a user is both a Manager and an App Admin, the global Admin
   privileges take precedence.
4. **Revocation**: Only the **Quiz Owner** or an **App Admin** can remove a Manager's access.

## 5. Quiz-Specific Leaderboards
Managers with the `canModerate` (or `can_moderate`) flag have access to the **Manual Leaderboard** system:
- **Scoping**: Boards are linked to the specific `quizId` and visible only within that quiz's context.
- **Top 10 Rule**: Only the top 10 unique users are stored.
- **Magic Wand Discovery**: Managers can auto-load the top 10 "First Attempts" from the response data to identify the true winners instantly.
- **Manual Control**: Final rankings must be saved/published manually by the manager.

