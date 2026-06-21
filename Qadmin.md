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

- **Owner**: The creator of the quiz. Has implicit full control (all permissions).
- **Manager**: A collaborator with specific granted permissions.
- **Participant**: (Restricted Quizzes) A user explicitly allowed to attempt a private or restricted
  quiz.

### 3.2 Granular Permissions (`permissions` map)

These flags control access to specific UI features and API operations:

| Flag Name          | Purpose                                                   |
|:-------------------|:----------------------------------------------------------|
| `can_update`       | Edit quiz metadata, questions, and marking schemes.       |
| `can_delete`       | Perform a soft-delete of the quiz.                        |
| `can_view_results` | View participant responses and answer keys.               |
| `canModerate`      | Soft-delete responses and ban/unban users from this quiz. |
| `can_ban_users`    | Specifically manage the ban list for this quiz.           |

> **Note on Naming:** There is currently a mix of snake_case (`can_update`) used in Firestore Rules
> and camelCase (`canModerate`) used in the Dart services. Both must be respected based on the context
> of the check.

---

## 4. Hierarchy & Management Rules

1. **Granting Access**: Only the **Quiz Owner** or an **App Admin** (Level 2+) can add a Manager to
   a quiz.
2. **App Admin Override**: Users with the global **Admin Mode** enabled bypass these checks and can
   manage any quiz on the platform.
3. **Conflict Resolution**: If a user is both a Manager and an App Admin, the global Admin
   privileges take precedence.
4. **Revocation**: Only the **Quiz Owner** or an **App Admin** can remove a Manager's access.
