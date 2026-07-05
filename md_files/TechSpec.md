# Technical Specification - ThinkFast

## 1. Architecture Overview
ThinkFast follows a layered architecture to ensure separation of concerns and maintainability.

- **Presentation Layer:** Flutter Widgets and BLoC/Provider (or stateful widgets for simpler views) managing UI state.
- **Service Facade:** `DatabaseService` acting as a unified entry point for all database operations, delegating to specialized domain services.
- **Domain Services:** Modular services handling specific business logic:
    - `UserService`: User profiles and private data management.
    - `QuizService`: Quiz lifecycle (CRUD), access control, and metadata.
    - `AttemptService`: Scoring logic, submission of attempts, and history.
    - `AiService`: Integration with AI for content generation and usage tracking.
    - `AdminService`: Elevated privilege management and audit logging.
    - `SettingsService`: Global configuration and feature flags.
- **Data Layer:** Firebase Firestore for NoSQL storage, Firebase Auth for security, and Firebase Storage for assets.

## 2. Data Models (Firestore Schema)

### 2.1 Users (`/users/{uid}`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | String | Display name. |
| `photoUrl` | String | URL to profile picture. |
| `createdAt` | Timestamp | Account creation time. |
| `lastActive` | Timestamp | Last activity tracking. |
| `quizCount` | Number | Total quizzes created by the user. |
| `attemptCount` | Number | Total quizzes attempted by the user. |

**Sub-collections:**
- `private/details`: Sensitive data like `email`, `activeQuizId`, and `activeQuizExpiry`.
- `protected/details`: Data readable by user/admin but writeable only by system/admin.

### 2.2 Quizzes (`/quizzes/{quizId}`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `creatorId` | String | UID of the creator. |
| `title` | String | Quiz title. |
| `description` | String | Quiz description. |
| `visibility` | String | `public` or `private`. |
| `time` | Number | Duration in seconds (0 means Unlimited). |
| `perQuestionTime` | Number | Independent countdown timer for every question. |
| `activeAt` | Timestamp | Scheduled start time for the quiz. |
| `isRestricted` | Boolean | If true, only allowed users can attempt. |
| `allowedParticipants` | Array | List of User UIDs allowed to attempt. |
| `markingScheme` | Map | Configuration for scoring (e.g., `default`, `per_question`, `per_question_type`). |
| `attemptLimits` | Map | Configuration for attempt constraints (e.g., `none`, `global`, `per_module`). |
| `isDeleted` | Boolean | Soft delete flag. |
| `deletedAt` | Timestamp | Time when the resource was soft deleted. |
| `deletedByType` | String | Role of the deleter (owner, manager, admin, user). |
| `isLocked` | Boolean | Prevents new attempts if true. |
| `modules` | Array | Organized list of question modules. |
| `totalQuestions`| Number | Total number of questions in the quiz. |

### 2.3 Quiz Content
- **Questions (`/quiz_questions/{quizId}`):** Stores an array of modules, where each module contains a list of questions (UID, type, text, options).
- **Answer Keys (`/answer_keys/{quizId}`):** Stores the mapping of question IDs to correct option IDs/values.
- **Quiz Stats (`/quiz_stats/{quizId}`):** Aggregate stats like total attempts, average score, and highest score.
- **Question Stats (`/quiz_question_stats/{questionId}`):** Performance metrics per question (total attempts, correct/wrong count).

### 2.4 Attempts & Responses
- **Global Responses (`/responses/{attemptId}`):** Root collection for all quiz attempts across the platform.
- **User Attempts (`/all_attempts/{attemptId}`):** Redundant copy or specific view of attempts.
- **Quiz-Specific Attempts (`/quiz_attempts/{quizId}/attempts/{attemptId}`):** Sub-collection for quick lookup of all attempts for a specific quiz.

### 2.5 AI & Usage
- **AI Generations (`/ai_generations/{id}`):** Logs of AI quiz generation prompts and results.
- **User Usage (`/user_usage/{uid}`):** Tracks daily AI quotas and activity (e.g., `aiGenerationsToday`).

## 3. Key Technical Implementations

### 3.1 Idempotency in Quiz Creation
To prevent duplicate quizzes due to network retries, `createQuiz` accepts a `clientToken`. The service checks for an existing quiz with the same `creatorId` and `clientToken` before proceeding with creation.

### 3.2 Dynamic Scoring Engine & Attempt Limits
The `AttemptService` calculates scores based on a flexible `markingScheme`:
- **Entire Quiz (Global):** Fixed points for correct/wrong answers across the entire quiz.
- **Per Question Type:** Different points for Single Choice, Multiple Choice, and Integer.
- **Per Question:** Specific points defined at the individual question level.

For **Integer** questions, the system performs a trimmed, case-insensitive string comparison between the user's input and the stored answer.

**Data Isolation & Anti-Cheating:**
The system enforces strict data isolation to prevent cheating:
1.  **Service-Level Stripping:** `DatabaseService.readDatabase` automatically strips any fields named `answers` or `correct_answer` from question modules before returning them to the UI.
2.  **No-Fetch Start:** The "Start Quiz" flow does not fetch the `answer_keys` document.
3.  **Global State Cleanup:** Starting a quiz resets all global answer caches (`global.correctAnswers`, `global.solutions`) to prevent leakage from previous review sessions.
4.  **UI Styling:** During quiz participation, the UI (e.g., `ButtonsOpt`) specifically avoids applying bold or highlight styles to correct answers, only showing them when `isReviewMode` is explicitly active.

**Attempt Limits (Select N out of M):**
The platform enforces attempt quotas per section or type. The `Quesations` screen tracks active selections and disables further input once the limit is reached for a specific module or question type, mimicking competitive exam logic.

**Timer Hierarchy:**
The quiz engine manages timing with the following precedence:
1.  **Individual Q Timer:** Specific duration for a single question.
2.  **Generalized Q Timer:** Default duration for all questions in the quiz.
3.  **Global Quiz Timer:** Cumulative duration for the entire session.
4.  **Unlimited:** Active if all of the above are set to 0.

Forward-only navigation is enforced when per-question timers are active to ensure exam integrity.

**Scheduling & Restrictions:**
Quizzes support scheduled activation via the `activeAt` timestamp. The system prevents participants from starting a quiz before this time. Additionally, `isRestricted` quizzes check the current user's UID against a comma-separated list of `allowedParticipants` during the start flow.

### 3.3 Enhanced Review Mode
Post-quiz analysis is handled by re-using the `Quesations` module in `isReviewMode`.
- **Navigator Colors:** Circle indicators use a gradient (Purple to Green/Red) if a question was both Marked for Review and answered.
- **Solution Layer:** Fetches solution descriptions from `answer_keys` and displays them in a dedicated card beneath the question.
- **State Preservation:** The "Marked for Review" state is persisted in the `responses` collection, allowing users to revisit their exam-time thought process.

### 3.4 Rate Limiting
A time-based rate limit is enforced on quiz creation. Users must wait a configurable interval (stored in `FeatureFlags`) between creating consecutive quizzes. Admins are exempt from this limit.

### 3.5 Deep Linking
Using the `app_links` package, the app handles URLs like `thinkfast.app/quiz?id=XYZ`.
- **Logic:** `_handleDeepLink` in `main.dart` extracts the `quizId` and navigates the user to the `QuizDetailsScreen` via the `navigatorKey`.

### 3.5 AI Usage Quotas
The `AiService` tracks daily generations per user. Before invoking AI generation, the system checks `aiGenerationsToday` against a quota to manage costs and prevent abuse.

## 4. Security Rules
- **Admin Overrides:** Designated administrators with `isAdminMode` enabled bypass standard ownership and rate-limiting checks. The platform uses a granular permission system (e.g., `manage_admins`, `moderate_users`) to authorize specific administrative actions.
- **Private Data:** Sensitive user information is stored in sub-collections with restricted read access.
- **Global Permission Guards:** Every database operation in `DatabaseService` is guarded by a feature flag check. If a feature (e.g., `enable_create_quiz`) is toggled off in `feature_flags`, only administrators can perform that action.

### 4.4 Soft Delete & Recovery Policy
When a quiz is soft-deleted (`isDeleted: true`):
- It is hidden from all public feeds and search results.
- It is moved to the creator's **Recycle Bin**.
- **Internal Data Protection:** Quiz managers and owners can only see the name and metadata; actual questions and answers are locked.
- **Admin Access:** App Administrators with `isAdminMode` enabled bypass these restrictions to audit moderated content.
- **Recovery Window:** Owners can restore a quiz from the Recycle Bin within **7 days** of deletion. After this period, the `restoreDatabase` operation will fail.
- **Bulk Actions:** Selection mode is triggered by long-pressing any item in moderation or history lists. This enables atomic batch operations for unbanning users, restoring responses, or soft-deleting data across multiple records.

Response/Attempt deletion follows a similar soft-delete pattern, attributing the action to the specific role (Owner, Manager, Admin, or User) in the `deletedByType` field.

## 5. Deployment & CI/CD
- **Firebase Hosting:** Web version (if applicable).
- **Firebase Cloud Functions:** (Planned) For server-side validation and automated cleanups.
- **Analytics:** Firebase Analytics tracks quiz starts, completions, and AI usage.

## 6. Recent Technical Enhancements (v1.1)

### 6.1 Brute-Force & Security
- **IP Detection**: Integrates with `api.ipify.org` to detect the user's public IP address during sensitive authentication flows.
- **Rate Limiting**: Tracks failed login attempts in `security_logs`. After 5 consecutive failures from the same IP, an automated 1-hour block is enforced at the service level.
- **Identity Purge**: Implemented a lifecycle policy that automatically deletes unverified Firebase Auth users and their associated Firestore records if they remain unverified for more than 7 days.

### 6.2 Compliance Engineering
- **Minor Safety (COPPA)**: The system implements an Age-Gate. If the detected or provided age is < 13, the `optInAiAnalysis` flag is hard-locked to `false`, preventing any collection of demographic or pedagogical preferences from minors.
- **Consent Persistence**: Privacy policy acceptance is stored in the `protected/details` sub-collection, which is immutable by the user after the initial write to ensure legal auditability.

### 6.3 AI Service Orchestration
- **Triple-Model sequential Fallback**: To mitigate API outages, `AiService` manages a list of 3 providers (Main, Backup 1, Backup 2). Upon failure of the primary model, the service automatically retries with the next available model in the sequence.
- **Admin Configuration**: Model names and the active starting index are managed via Global Feature Flags, allowing zero-downtime provider switching.

### 6.4 Real-time Notification Engine
- **Reactive Merging**: Utilizes `RxDart`'s `combineLatest2` to merge two independent Firestore streams (Personal UID-based alerts and Global system-wide broadcasts) into a single, sorted UI list.
- **Event Bus Triggers**: Submission success and public publishing events trigger background writes to the notification collections, ensuring low-latency alerts.

### 6.5 Local Caching Strategy
- **Shared Preferences**: Utilizes `shared_preferences` to maintain a persistent local list of the last 10 quizzes visited. This reduces Firebase read overhead for frequent quiz-takers and improves app responsiveness.

