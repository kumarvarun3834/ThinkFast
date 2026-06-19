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
| `time` | Number | Duration in seconds. |
| `markingScheme` | Map | Configuration for scoring (e.g., `default`, `per_question`, `per_question_type`). |
| `isDeleted` | Boolean | Soft delete flag. |
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

### 3.2 Dynamic Scoring Engine
The `AttemptService` calculates scores based on a flexible `markingScheme`:
- **Entire Quiz (Global):** Fixed points for correct/wrong answers across the entire quiz.
- **Per Question Type:** Different points for Single Choice, Multiple Choice, and Integer.
- **Per Question:** Specific points defined at the individual question level.

For **Integer** questions, the system performs a trimmed, case-insensitive string comparison between the user's input and the stored answer.

### 3.3 Rate Limiting
A time-based rate limit is enforced on quiz creation. Users must wait a configurable interval (stored in `FeatureFlags`) between creating consecutive quizzes. Admins are exempt from this limit.

### 3.4 Deep Linking
Using the `app_links` package, the app handles URLs like `thinkfast.app/quiz?id=XYZ`.
- **Logic:** `_handleDeepLink` in `main.dart` extracts the `quizId` and navigates the user to the `QuizDetailsScreen` via the `navigatorKey`.

### 3.5 AI Usage Quotas
The `AiService` tracks daily generations per user. Before invoking AI generation, the system checks `aiGenerationsToday` against a quota to manage costs and prevent abuse.

## 4. Security Rules
- **Authentication:** All core write operations require a verified email.
- **Ownership:** Creators can update/delete their own quizzes.
- **Admin Overrides:** Users with the `admin` role in their profile (or `isAdminMode` enabled) bypass standard ownership and rate-limiting checks.
- **Private Data:** Sensitive user information is stored in sub-collections with restricted read access.

### 4.4 Soft Delete Policy
When a quiz is soft-deleted (`isDeleted: true`):
- It is hidden from all public feeds and search results.
- It is removed from the creator's "My Quizzes" dashboard.
- Any attempt to access it via direct ID or deep link by a regular user or the owner results in a "Quiz not found" error.
- App Administrators with `isAdminMode` enabled bypass these restrictions and can view the quiz and its responses.

## 5. Deployment & CI/CD
- **Firebase Hosting:** Web version (if applicable).
- **Firebase Cloud Functions:** (Planned) For server-side validation and automated cleanups.
- **Analytics:** Firebase Analytics tracks quiz starts, completions, and AI usage.
