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
- **`quiz_service.dart`**: Manages CRUD operations for quizzes. Uses a highly secure storage pattern:
    - **Metadata**: Stored in `quizzes` collection.
    - **Questions & Options**: Stored in `quiz_questions` collection (Separate document per quiz).
    - **Answer Keys**: Stored in `answer_keys` collection. Only accessible via secure service calls during submission/scoring to prevent front-end leaks.
    - **Access Control**: Implements `hasAccess()` to check visibility, creator status, or explicit permissions in `quiz_access`.

- **`admin_service.dart`**: Provides administrative and management capabilities:
    - **Quiz Management**: Allows owners to grant/remove management access to other users with specific permissions. Managers can also "Quit" management roles.
    - **Audit Logs**: Tracks critical actions (access grants, master updates, deletions) for accountability.
    - **Master Control**: Allows App Admins to view, update, or delete any quiz regardless of ownership or visibility.
    - **Banning**: Capabilities to restrict specific users from participating in quizzes.

- **`settings_service.dart`**: Centralized control for App Settings and **Feature Flags**:
    - **Live Toggle**: Flags can be streamed for real-time app updates (e.g., turning off registration during maintenance).
    - **Specific Flags**: Includes `enable_ai`, `enable_login`, `enable_register`, `maintenance_mode`, `random_quiz_generator`, `user_action_logging`, and `management_features`.

- **`attempt_service.dart`**: Handles the logic for submitting quiz attempts and calculating scores.
- **`user_service.dart`**: Manages user profile data.
- **`notification_service.dart`**: Handles app notifications.

### 5. Utilities & State (`lib/utils/`)
- **`global.dart`**: Centralized state management. Stores `quizData` (current quiz questions), `quizResult` (user answers), and app-wide theme colors.

### 6. Common Widgets (`lib/widgets/`)
- Reusable UI components like `opt_buttons.dart` (choices), `TextContainer.dart`, and custom navigation drawers.

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
