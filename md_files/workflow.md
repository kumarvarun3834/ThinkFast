# ThinkFast Project Workflow & File Linkage

ThinkFast is a Flutter-based quiz application that allows users to create, participate in, and manage quizzes. It uses Firebase for authentication, real-time data storage, and analytics.

## 📁 Project Structure Overview

### 1. Entry Point
- **`lib/main.dart`**: The application's entry point. It initializes Firebase, sets up deep linking, configures the `MaterialApp` theme, and defines the routing logic (`onGenerateRoute`).

### 2. Authentication Flow (`lib/auth/`)
- **`login_screen.dart`**: Handles user login via Email/Password and Google Sign-In.
- **`signup_screen.dart`**: Handles new user registration.
- **`verification_screen.dart`**: Manages email verification state.
- **`auth_service.dart`**: Contains the logic for interacting with Firebase Auth.

### 3. Core Screens (`lib/screens/`)
- **`splash_screen.dart`**: Initial loading screen that checks authentication status.
- **`start_screen.dart`**: The main dashboard. Users can browse available quizzes, see "My Quizzes," or search for specific quiz IDs.
- **`quiz_details_screen.dart`**: Displays information about a selected quiz (title, description, time limit) before starting.
- **`quesations.dart`**: The main quiz-taking engine.
    - **Shuffling Logic**: Groups by subject/module, shuffles subjects, then orders questions by type: **Single Choice -> Multiple Choice -> Integer**. Questions are shuffled internally within each type group, and options are shuffled for each question.
    - **UI Features**: Includes "Mark for Review" (Purple highlights), "Review & Next", "Clear Selection", and navigation.
    - **Submission**: Shows a confirmation grid summary (Answered: Green, Review: Purple, Seen: Blue, Unseen: Grey) before final submission.
    - **Session**: Creation of a session on Firebase with an expiry token (Duration + 5 mins buffer) to prevent multiple parallel attempts or stale sessions.
    - Uses `PopScope` to prevent accidental exits.
- **`result_screen.dart`**: Displays the user's score, time taken, and a detailed breakdown of correct/incorrect answers.
- **`quiz_form.dart`**: The interface for creating or editing a quiz.
- **`my_attempts_screen.dart`**: Shows a history of quizzes the user has participated in.
- **`quiz_responses_screen.dart`**: Allows quiz creators to view responses from participants.

### 4. Services Layer (`lib/services/`)
#### A. Base Services
- **`quiz_service.dart`**: Manages CRUD operations for quizzes. Uses a highly secure storage pattern:
    - **Metadata**: Stored in `quizzes` collection.
    - **Questions & Options**: Stored in `quiz_questions` collection (Separate document per quiz).
    - **Answer Keys**: Stored in `answer_keys` collection. Only accessible via secure service calls during submission/scoring to prevent front-end leaks.
    - **Access Control**: Implements `hasAccess()` to check visibility, creator status, or explicit permissions in `quiz_access`.

- **`admin_service.dart`**: Provides administrative and management capabilities:
    - **Quiz Management**: Allows owners to grant/remove management access to other users with specific permissions.
    - **Audit Logs**: Tracks critical actions (access grants, master updates, deletions).
    - **Banning**: Capabilities to restrict specific users from participating in quizzes.

- **`settings_service.dart`**: Centralized control for App Settings and **Feature Flags**.
- **`attempt_service.dart`**: Handles the logic for submitting quiz attempts and calculating scores.
- **`user_service.dart`**: Manages user profile data.
- **`ai_service.dart`**: Handles communication with the AI engine for quiz generation.

#### B. Database Connect Layers (`lib/services/firebase/`)
- **`user_connect.dart`**: High-performance facade for the normal user experience (Session init, history, taking quizzes).
- **`q_admin_connect.dart`**: Dedicated interface for quiz lifecycle management, team collaboration, and tag synchronization.
- **`admin_connect.dart`**: Secure interface for platform-wide administrative operations and master controls.
- **`ai_connect.dart`**: Bridge for AI-powered features, usage logging, and generation history.

### 5. Utilities & State (`lib/utils/`)
- **`global.dart`**: Centralized state management. Stores global instances of the Connect layers (`userConnect`, `adminConnect`, `qAdminConnect`, `aiConnect`) and app-wide theme colors.

### 6. Common Widgets (`lib/widgets/`)
- Reusable UI components like `opt_buttons.dart` (choices), `text_container.dart`, and custom navigation drawers.

---

## 🔗 File Linkage & Data Flow

1.  **Launch**: `main.dart` -> `splash_screen.dart`.
2.  **Auth**: If not logged in -> `login_screen.dart`. If logged in -> `start_screen.dart`.
3.  **Browsing**: `start_screen.dart` fetches quizzes via `quiz_service.dart`.
4.  **Quiz Selection**: `start_screen.dart` -> `quiz_details_screen.dart` (passes `quizId`).
5.  **Taking Quiz**: 
    - `quiz_details_screen.dart` fetches full quiz data and populates `global.quizData`.
    - Navigates to `quesations.dart`.
    - Participant answers questions; state is updated in `global.quizResult`.
6.  **Submission**:
    - `quesations.dart` calls `attempt_service.submitAttempt()`.
    - Navigates to `result_screen.dart`.
7.  **Results**: `result_screen.dart` displays performance based on the data stored in `global.quizResult`.

---

## 🎨 Theme & UI
The app uses a consistent dark theme defined in `global.dart`:
- **Background**: `0xFF0F172A` (Deep Blue/Black)
- **Cards/Surfaces**: `0xFF1E293B` (Slate)
- **Primary Accent**: `0xFF3B82F6` (Bright Blue)

---

## 🚀 Recent Architecture Updates (v1.1)

### New Services & Data Handlers
- **`notification_service.dart`**: Core logic for pushing reactive personal and global alerts using RxDart.
- **`local_cache_service.dart`**: Manages persistent local history of the last 10 recently viewed quizzes using `shared_preferences`.
- **`security_logs`**: Background service detecting public IPs and tracking failed login attempts for brute-force prevention.

### Revised Interaction Flow
1.  **Quiz Discovery**: Users now see a "RECENTLY VIEWED" horizontal list populated by `LocalCacheService`.
2.  **Taking Quiz**: Every successful quiz entry triggers a local cache update and a background check for active session validity.
3.  **Submission**:
    - `AttemptService` calculates scores and pushes an atomic batch to Firestore.
    - Immediately triggers `NotificationService` to send a personal result alert.
    - **New**: Triggers `AiService.analyzeAttempt` for users with personalization enabled, saving results to `/explanation`.
4.  **Compliance Loop**: 
    - `profile_screen.dart` serves as the primary controller for mandatory privacy consent and optional AI demographic collection.
    - Status is synchronized with the user's `protected/details` sub-collection for backend enforcement.
    - **Advanced Gate**: AI Wizard and Result Screen gate "starred ⭐" features and deep analysis based on the `optInAiAnalysis` status.

### AI Lifecycle Flow
1.  **Generation**: Client calls `/generateQuiz` -> Backend returns `quizId` + `explanation` -> Backend saves insight to `/explanation/{uid}/gen/{quizId}`.
2.  **Tracking**: Quotas are incremented by the server in `user_usage`.
3.  **Maintenance**: AI quizzes are updated via `PUT /api/quizzes/:quizId` -> Backend removes AI flag + adds "partial AI" tag + deletes generation log.
4.  **Analysis**: Result screen triggers `/api/quiz/analyze` -> Backend saves evaluation to `/explanation/{uid}/{quizId}/{attemptId}`.

