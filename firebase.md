# Firebase Firestore Data Structure - ThinkFast (Production)

This document outlines the schema for the Firestore database used in the ThinkFast application,
aligned with the production security rules and architecture.

## 1. Collection: `quizzes`

Stores the main quiz metadata and question content. (Note: Previously named `databases`).

### Document Fields

| Field                 | Type            | Description                                                                     |
|:----------------------|:----------------|:--------------------------------------------------------------------------------|
| `creatorId`           | `String`        | The unique UID of the user who created the quiz.                                |
| `user`                | `String`        | Display identifier (email/phone) of the creator.                                |
| `title`               | `String`        | The title of the quiz set.                                                      |
| `titleLower`          | `String`        | Lowercase title for optimized search queries.                                   |
| `description`         | `String`        | A short description of the quiz content.                                        |
| `tags`                | `array<string>` | Searchable keywords (e.g., ["physics", "math", "neet"]).                        |
| `visibility`          | `String`        | Access level: `public`, `private`, or `protected`.                              |
| `time`                | `number`        | Total allowed time in **seconds**.                                              |
| `createdAt`           | `timestamp`     | Server timestamp when the quiz was created.                                     |
| `updatedAt`           | `timestamp`     | Server timestamp when the quiz was last modified.                               |
| `isRestricted`        | `boolean`       | If true, only specified users can attempt this quiz.                            |
| `allowedParticipants` | `array<string>` | List of UIDs permitted to attempt the quiz (used if restricted).                |
| `isDeleted`           | `boolean`       | Soft delete flag for recovery and audits.                                       |
| `deletedAt`           | `timestamp`     | Timestamp when the quiz was soft-deleted.                                       |
| `deletedBy`           | `String`        | UID of the user/admin who deleted the quiz.                                     |
| `isLocked`            | `boolean`       | If true, no more responses can be taken (quiz remains public).                  |
| `allowMultipleAttempts` | `boolean`     | If false, each user can only submit one response.                               |
| `markingScheme`         | `map`         | Configuration for scoring (see [Marking Scheme](#marking-scheme-structure)).    |
| `modules`               | `array<map>`  | A list of subject-based modules (see [Module Structure](#module-structure)).   |

### Module Structure (`modules` field)

| Field       | Type         | Description                                     |
|:------------|:-------------|:------------------------------------------------|
| `subject`   | `String`     | Name of the subject/module.                     |
| `questions` | `array<map>` | List of questions (see [Question Structure]). |

### Question Structure

Format:
`{ "uid": "qUid", "type": "Single Choice | Multiple Choice | Integer", "Q": { "id": "qUid", "text": "..." }, "Opt": [...] }`

### Marking Scheme Structure (`markingScheme` field)

| Field             | Type       | Description                                                                              |
| :---------------- | :--------- | :--------------------------------------------------------------------------------------- |
| `type`            | `String`   | `default`, `entire_quiz`, `per_question_type`, or `per_question`.                        |
| `global`          | `map`      | Scheme for `entire_quiz`: `{ "correct": number, "wrong": number }`.                      |
| `perQuestionType` | `map<map>` | Scheme for `per_question_type`: `{ "mcq": { "correct": 4, "wrong": -1 }, ... }`.         |
| `perQuestion`     | `map<map>` | Scheme for `per_question`: `{ "qUid": { "correct": 5, "wrong": -2 }, ... }`.             |

---

## 2. Collection: `answer_keys`

Stores correct answers in an isolated directory. Document ID matches the `{quizId}` from
`quizzes`.

### Document Fields

| Field        | Type         | Description                                                      |
|:-------------|:-------------|:-----------------------------------------------------------------|
| `quizId`     | `String`     | Foreign key to the parent quiz.                                  |
| `answerkeys` | `array<map>` | List of answer mappings: `[{ "q": "qUid", "a": "optUid" }, ...]` |
| `createdAt`  | `timestamp`  | Timestamp for tracking.                                          |

---

## 3. Collection: `responses`

Track user attempt history. Organized as a flat collection for global reporting and filtering.

### Document Fields

| Field            | Type        | Description                                      |
|:-----------------|:------------|:-------------------------------------------------|
| `quizId`         | `String`    | Reference to the quiz document.                  |
| `userId`         | `String`    | UID of the user who took the quiz.               |
| `quizTitle`      | `String`    | Display title of the quiz.                       |
| `score`          | `number`    | Final calculated score based on marking scheme.  |
| `totalQuestions` | `number`    | Number of questions in the quiz.                 |
| `answers`        | `map`       | User selections: `{ "qUid": ["optUid", ...] }`.  |
| `status`         | `number`    | 1 = Completed.                                   |
| `timestamp`      | `timestamp` | Server timestamp of the attempt.                 |

---

## 4. Collection: `all_attempts`

**The Flat Global Log.** Stores a replica of every attempt to facilitate cross-user reporting for
owners and admins.

### Document Path: `all_attempts/{attemptId}`

Fields are identical to the `responses` document.

---

## 5. Collection: `quiz_attempts`

**Creator Dashboard Optimization.** Stores attempts grouped by quiz ID for faster querying by quiz
owners.

### Document Path: `quiz_attempts/{quizId}/attempts/{attemptId}`

Fields are identical to the `responses` document.

---

## 6. Collection: `users`

Stores profile information, activity tracking, and data for AI-driven features.

### Document Path: `users/{userId}` (Public)

| Field          | Type        | Description                                |
|:---------------|:------------|:-------------------------------------------|
| `name`         | `String`    | Display name.                              |
| `photoUrl`     | `String`    | URL to user's profile picture.             |
| `bio`          | `String`    | Short user biography.                      |
| `quizCount`    | `number`    | Cached count of quizzes created.           |
| `attemptCount` | `number`    | Cached count of quizzes attempted.         |
| `createdAt`    | `timestamp` | Account creation date.                     |
| `lastActive`   | `timestamp` | Updated automatically on every submission. |

### Document Path: `users/{userId}/protected/details` (Protected)

Visible to the user and moderators. Used for AI quiz generation context.

| Field                 | Type            | Description                                  |
|:----------------------|:----------------|:---------------------------------------------|
| `class`               | `String`        | Educational grade or level.                  |
| `age`                 | `String`        | User's age group or age.                     |
| `goal`                | `String`        | Primary goal for using ThinkFast.            |
| `interests`           | `array<String>` | Topics the user is interested in.            |
| `learningTopics`      | `array<String>` | Specific subjects the user wants to study.   |
| `preferredDifficulty` | `String`        | AI preference: `easy`, `medium`, `hard`.     |
| `preferredLanguage`   | `String`        | AI preference for quiz language.             |
| `weakTopics`          | `array<String>` | Topics user struggles with.                  |
| `strongTopics`        | `array<String>` | Topics user excels in.                       |
| `topicPerformance`    | `map<number>`   | AI metrics: `{ "math": 85, "physics": 63 }`. |
| `studyHoursPerWeek`   | `number`        | Weekly commitment level.                     |
| `lastQuizTopics`      | `array<String>` | Topics from recently completed quizzes.      |
| `updatedAt`           | `timestamp`     | Last time this section was modified.         |

### Document Path: `users/{userId}/private/details` (Private)

Visible ONLY to the user.

| Field       | Type        | Description               |
|:------------|:------------|:--------------------------|
| `email`     | `String`    | Registered email address. |
| `activeQuizId` | `String`  | ID of the quiz currently being attempted (to prevent multiple sessions). |
| `activeQuizExpiry` | `timestamp` | Time when the active session expires (to allow cleanup after glitches). |
| `updatedAt` | `timestamp` | Last update time.         |

---

## 7. Collection: `admins` (App Management)

Managed by the **App Owner**. Controls global settings and overall platform moderation.

### Document Fields

| Field              | Type            | Description                                          |
|:-------------------|:----------------|:-----------------------------------------------------|
| `level`            | `number`        | Role level: 1 (Moderator), 2 (Super Admin).          |
| `allowed_features` | `array<string>` | List of granted permissions (e.g., `edit_any_quiz`). |
| `role`             | `string`        | Descriptive name of the role.                        |
| `updatedAt`        | `timestamp`     | Last update.                                         |

---

## 8. Collection: `quiz_access` (Quiz Management)

Managed by the **Quiz Owner**. Allows delegation of a specific quiz's administration to other users.
**Document ID Format:** `{quizId}_{userId}`

### Document Fields

| Field                  | Type        | Description                                          |
|:-----------------------|:------------|:-----------------------------------------------------|
| `quizId`               | `String`    | The quiz being managed.                              |
| `userId`               | `String`    | The user granted management rights.                  |
| `permissions`          | `map`       | Permissions for this specific quiz.                  |
| └ `can_update`         | `boolean`   | Can edit questions and metadata.                     |
| └ `can_view_results`   | `boolean`   | Can see user scores and answers.                     |
| └ `can_ban_users`      | `boolean`   | Can block users from this specific quiz.             |
| └ `can_manage_access`  | `boolean`   | Can add/remove other managers (Disabled by default). |
| └ `can_delete`         | `boolean`   | Can soft-delete the quiz.                            |
| └ `can_export_results` | `boolean`   | Can generate reports/exports.                        |
| `addedBy`              | `String`    | UID of the person who granted access.                |
| `updatedAt`            | `timestamp` | Last update time.                                    |

---

## 9. Collection: `settings`

Used for app-wide maintenance mode and global configs.

### Document Path: `settings/app`

| Field                | Type        | Description                              |
|:---------------------|:------------|:-----------------------------------------|
| `allowQuizCreation`  | `boolean`   | Global toggle for quiz creation.         |
| `allowRegistration`  | `boolean`   | Global toggle for new user signups.      |
| `allowPublicQuizzes` | `boolean`   | Toggle for visibility of public quizzes. |
| `maintenanceMode`    | `boolean`   | Locks app with a maintenance screen.     |
| `minimumAppVersion`  | `number`    | Enforce app updates.                     |
| `updatedAt`          | `timestamp` | Last update time.                        |

---

## 10. Collection: `feature_flags`

Host controlled flags for rolling out features.

### Document Path: `feature_flags/production`

| Field              | Type        | Description                               |
|:-------------------|:------------|:------------------------------------------|
| `aiQuizGeneration` | `boolean`   | Enable AI-driven quiz creation.           |
| `quizManagement`   | `boolean`   | Enable delegated quiz management.         |
| `analytics`        | `boolean`   | Enable usage tracking/analytics features. |
| `quizSharing`      | `boolean`   | Enable external link sharing.             |
| `leaderboards`     | `boolean`   | Enable competitive scoring UI.            |
| `updatedAt`        | `timestamp` | Last update time.                         |

---

## 11. Collection: `quiz_bans`

Tracks bans on a per-quiz basis.

### Document ID: `{quizId}_{userId}`

| Field       | Type        | Description                         |
|:------------|:------------|:------------------------------------|
| `quizId`    | `String`    | ID of the quiz.                     |
| `userId`    | `String`    | ID of the banned user.              |
| `reason`    | `String`    | Why the user was banned.            |
| `bannedBy`  | `String`    | UID of the manager who banned them. |
| `createdAt` | `timestamp` | When the ban was issued.            |

---

## 12. Collection: `quiz_stats`

Aggregated analytics for quizzes to avoid expensive queries.

### Document ID: `{quizId}`

| Field            | Type        | Description                                 |
|:-----------------|:------------|:--------------------------------------------|
| `attempts`       | `number`    | Total number of times quiz was taken.       |
| `uniqueUsers`    | `number`    | Number of distinct users who took the quiz. |
| `averageScore`   | `number`    | Average score across all attempts.          |
| `completionRate` | `number`    | Percentage of users who finished.           |
| `lastAttemptAt`  | `timestamp` | Time of the most recent attempt.            |

---

## 13. Collection: `reports`

Moderation queue for user-submitted reports.

### Document Fields

| Field         | Type        | Description                             |
|:--------------|:------------|:----------------------------------------|
| `quizId`      | `String`    | ID of the reported quiz.                |
| `reportedBy`  | `String`    | UID of the user reporting.              |
| `reason`      | `String`    | Category of report (e.g., spam, error). |
| `description` | `String`    | Detailed explanation.                   |
| `status`      | `String`    | `pending`, `reviewed`, `resolved`.      |
| `createdAt`   | `timestamp` | When report was created.                |

---

## 14. Collection: `quiz_question_stats`

Granular analytics per question to identify difficulty and patterns.

### Document ID: `{questionId}`

| Field      | Type     | Description                               |
|:-----------|:---------|:------------------------------------------|
| `quizId`   | `String` | Foreign key to the parent quiz.           |
| `attempts` | `number` | Total attempts on this specific question. |
| `correct`  | `number` | Count of correct answers.                 |
| `wrong`    | `number` | Count of wrong answers.                   |

---

## 15. Collection: `audit_logs`

Platform-wide activity tracking for moderation and security auditing.

### Document Fields

| Field       | Type        | Description                                      |
|:------------|:------------|:-------------------------------------------------|
| `actorId`   | `String`    | UID of the user who performed the action.        |
| `action`    | `String`    | e.g., `DELETE_QUIZ`, `BAN_USER`, `GRANT_ACCESS`. |
| `targetId`  | `String`    | ID of the quiz/user affected.                    |
| `details`   | `String`    | Additional context.                              |
| `timestamp` | `timestamp` | Server timestamp of the action.                  |

---

## 16. Collection: `notifications`

User-facing system and activity notifications.

### Document Fields

| Field       | Type        | Description                   |
|:------------|:------------|:------------------------------|
| `userId`    | `String`    | Target user UID.              |
| `title`     | `String`    | Notification heading.         |
| `body`      | `String`    | Notification content.         |
| `read`      | `boolean`   | Status flag.                  |
| `createdAt` | `timestamp` | Server timestamp of creation. |

---

[//]: # (## 17. Collection: `leaderboards`)

[//]: # ()

[//]: # (Precomputed rankings to optimize UI performance.)

[//]: # ()

[//]: # (### Document Fields)

[//]: # ()

[//]: # (| Field       | Type        | Description                      |)

[//]: # (|:------------|:------------|:---------------------------------|)

[//]: # (| `userId`    | `String`    | User UID.                        |)

[//]: # (| `score`     | `number`    | Aggregated competitive score.    |)

[//]: # (| `rank`      | `number`    | Computed rank position.          |)

[//]: # (| `updatedAt` | `timestamp` | Last time the rank was computed. |)

[//]: # ()

[//]: # (---)

## 18. Collection: `ai_generations`

History and logging for AI-driven quiz creation.

### Document Fields

| Field             | Type        | Description                            |
|:------------------|:------------|:---------------------------------------|
| `userId`          | `String`    | UID of the requester.                  |
| `prompt`          | `String`    | The context/prompt provided to the AI. |
| `generatedQuizId` | `String`    | Resulting document ID in `quizzes`.    |
| `createdAt`       | `timestamp` | Server timestamp.                      |

---

## 19. Collection: `user_usage`

Quota management and rate limiting (especially for expensive AI features).

### Document ID: `{userId}`

| Field                | Type        | Description                            |
|:---------------------|:------------|:---------------------------------------|
| `aiGenerationsToday` | `number`    | Usage counter for the current window.  |
| `lastReset`          | `timestamp` | Last time the usage counter was reset. |

---

## Final Collection List Summary

1. `quizzes` (Main Metadata + Questions)
2. `answer_keys` (Validation)
3. `responses` (Personal History)
4. `all_attempts` (Global Admin Log)
5. `quiz_attempts` (Creator Analytics Root)
6. `users` (Profiles & AI Context)
7. `admins` (Platform Staff)
8. `quiz_access` (Delegated Permissions)
9. `settings` (App Health)
10. `feature_flags` (Product Strategy)
11. `quiz_bans` (Access Control)
12. `quiz_stats` (Analytics Aggregation)
13. `reports` (Moderation Queue)
14. `quiz_question_stats` (Difficulty Tracking)
15. `audit_logs` (Security History)
16. `notifications` (User Alerts)
17. `leaderboards` (Precomputed Rankings)
18. `ai_generations` (AI Request Log)
19. `user_usage` (Quota Management)

---

Note: If a settings field or document doesn't exist, it should be created in-place during the next
update/access.
