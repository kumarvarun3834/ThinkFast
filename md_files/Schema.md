# Database Schema - ThinkFast

## 1. Users Collection (`/users/{uid}`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | String | Display name. |
| `photoUrl` | String | URL to profile picture. |
| `createdAt` | Timestamp | Account creation time. |
| `lastActive` | Timestamp | Last activity tracking. |
| `quizCount` | Number | Total quizzes created. |
| `attemptCount` | Number | Total quizzes attempted. |

### 1.1 Private Sub-collection (`/users/{uid}/private/details`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `email` | String | User's email address. |
| `activeQuizId` | String | ID of the quiz currently being taken. |
| `activeQuizExpiry` | Timestamp | Expiration time for the active session. |
| `updatedAt` | Timestamp | Last document update. |

## 2. Quizzes Collection (`/quizzes/{quizId}`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `creatorId` | String | UID of the creator. |
| `title` | String | Quiz title. |
| `description` | String | Quiz description. |
| `visibility` | String | `public` or `private`. |
| `time` | Number | Duration in seconds (0 means Unlimited). |
| `perQuestionTime` | Number | Default duration in seconds for every question (0 if disabled). |
| `activeAt` | Timestamp | Scheduled start time for the quiz. |
| `isRestricted` | Boolean | If true, only allowed users can attempt. |
| `allowedParticipants` | Array | List of User UIDs allowed to attempt. |
| `markingScheme` | Map | Config: `{type: 'default'|'per_question'|'per_question_type', global: {}, perQuestion: {}, perQuestionType: {}}`. |
| `attemptLimits` | Map | Config: `{type: 'none'|'global'|'per_module', global: {}, perModule: {}}`. |
| `isDeleted` | Boolean | Soft delete flag. |
| `deletedAt` | Timestamp | Time when the resource was soft deleted. |
| `deletedBy` | String | UID of the user who deleted the resource. |
| `deletedByType` | String | Role of the deleter (owner, manager, admin, user). |
| `isLocked` | Boolean | Prevents new attempts. |
| `modules` | Array | Ordered modules containing question metadata. |
| `totalQuestions` | Number | Count of questions. |

## 3. Quiz Content & Keys
- **Questions (`/quiz_questions/{quizId}`):** Document containing a `modules` array.
- **Answer Keys (`/answer_keys/{quizId}`):** Document mapping `questionId -> List<String>` (correct options).

## 4. Attempts & Analytics
### 4.1 Global Responses (`/responses/{attemptId}`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `userId` | String | Participant UID. |
| `quizId` | String | Attempted Quiz ID. |
| `quizTitle` | String | Denormalized quiz title. |
| `score` | Number | Points earned. |
| `totalQuestions` | Number | Total questions in quiz. |
| `answers` | Map | `{questionId: selection}`. |
| `reviewItems` | List<String> | List of question IDs marked for review during the session. |
| `isDeleted` | Boolean | Soft delete flag. |
| `deletedByType` | String | Role of the deleter (owner, manager, admin, user). |
| `deleteReason` | String | Reason for soft deletion. |
| `status` | Number | Attempt status (e.g., 1 for completed). |
| `timestamp` | Timestamp | Submission time. |

### 4.2 Quiz Stats (`/quiz_stats/{quizId}`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `totalAttempts` | Number | Aggregate attempts. |
| `avgScore` | Number | Average score achieved. |

### 4.3 Question Stats (`/quiz_question_stats/{questionId}`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `quizId` | String | Parent quiz ID. |
| `attempts` | Number | Total times answered. |
| `correct` | Number | Count of correct answers. |
| `wrong` | Number | Count of incorrect answers. |

## 5. AI & Infrastructure
### 5.1 AI Logs (`/ai_generations/{id}`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `userId` | String | User who triggered generation. |
| `prompt` | String | Input prompt. |
| `generatedQuizId` | String | Resulting Quiz ID. |
| `createdAt` | Timestamp | Creation time. |

### 5.2 User Usage (`/user_usage/{uid}`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `aiGenerationsToday` | Number | Daily usage counter. |
| `lastReset` | Timestamp | Last counter reset time. |

### 5.3 Audit Logs (`/audit_logs/{id}`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `actorId` | String | UID of the performer. |
| `action` | String | Action type (e.g., `delete_quiz`, `bulk_update_admins`). |
| `targetId` | String | ID of affected resource. |
| `category` | String | e.g., `admin`, `quiz`, `moderation`. |
| `timestamp` | Timestamp | Log time. |

## 6. Administrative & Team Access
### 6.1 Admin Records (`/admins/{userId}`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `permissions` | List<String> | Active platform permissions. |
| `level` | Number | `0` for Super User, `1+` for sub-admins. |
| `isAdminModeEnabled` | Boolean | UI experience toggle. |
| `addedBy` | String | Granting admin UID. |
| `updatedAt` | Timestamp | Last record update. |

### 6.2 Quiz Access (`/quiz_access/{quizId}_{userId}`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `quizId` | String | Target Quiz. |
| `userId` | String | Grantee UID. |
| `role` | String | `manager` or `participant`. |
| `permissions` | Map<String, Boolean> | Granular manager flags. |
| `addedBy` | String | Granting user UID. |

### 6.3 Banned Users (`/banned_users/{banId}`)
- **Format:** `global_{userId}` or `{quizId}_{userId}`.
- **Fields:** `userId`, `quizId` (null for global), `reason`, `bannedBy`, `createdAt`.
