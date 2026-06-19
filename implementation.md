# Implementation Details - ThinkFast

## 1. Project Structure
The codebase is organized into a modular directory structure to separate UI, business logic, and utilities.

```text
lib/
├── auth/           # Authentication screens (Login, Signup, Verification)
├── screens/        # Primary feature screens
│   ├── admin/      # Administrator panel and tools
│   ├── profile/    # User profile management
│   ├── quiz/       # Quiz participation and details
│   └── moderation/ # Content moderation tools
├── services/       # Domain-specific business logic and Firebase interaction
├── utils/          # Global constants, helpers, and theme definitions
├── widgets/        # Reusable UI components
└── main.dart       # App entry point, routing, and deep link initialization
```

## 2. Core Dependencies
Key packages used in the implementation:
- **Firebase:** `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`.
- **Navigation & Deep Linking:** `app_links` for handling `/quiz?id=...` URLs.
- **UI & Styling:** `google_fonts` (Poppins), `flutter_svg`.
- **Utilities:** `http` for AI API calls (if external), `intl` for date formatting.

## 3. Service Layer Architecture
ThinkFast uses a **Facade Pattern** combined with **Domain Services**.

### 3.1 Domain Services
Located in `lib/services/`, these services handle specific collections or logic:
- `QuizService`: Manages the `quizzes`, `quiz_questions`, and `answer_keys` collections.
- `UserService`: Manages user profiles and sensitive data in sub-collections.
- `AttemptService`: Handles scoring logic and the `responses` collection.
- `AiService`: Manages AI generation logs and quotas.
- `AnalyticsService`: Tracks quiz-level and question-level performance statistics.
- `AdminService`: Handles audit logging and platform-wide configurations.

### 3.2 The Unified Database Service (`DatabaseService`)
Located in `lib/services/firebase_direct_commands.dart`, this class acts as a central hub. Instead of UI code interacting with multiple services, it calls `DatabaseService`, which coordinates the necessary domain services. This simplifies the UI-to-Logic interface.

## 4. Key Implementation Logic

### 4.1 Quiz Data Transformation
Quizzes are stored in a normalized way to optimize for quiz-taking performance and security:
- **Metadata** is stored in the `quizzes` collection.
- **Questions** (without answers) are stored in `quiz_questions`.
- **Answers** are stored separately in `answer_keys` to prevent cheating via client-side inspection of the questions document.
- The `_transformQuizData` method in `DatabaseService` handles converting the editor's flat list into this multi-collection structure.

### 4.2 Scoring Engine
Scoring is performed by the `AttemptService` and mirrored in the `ResultScreen` UI for immediate feedback. It supports:
- **Single Choice:** Equality check on option IDs.
- **Multiple Choice:** Set-based comparison (all correct must be selected, no wrong ones).
- **Integer:** Trimmed string comparison.
- **Marking Schemes:** The engine dynamically pulls point values from the quiz's `markingScheme` map, supporting global, per-type, and per-question configurations.

### 4.3 Deep Link Routing
In `main.dart`, the `AppLinks` stream is initialized at startup. When a link is detected:
1. The URI is parsed to extract the `id`.
2. The `navigatorKey` is used to push the `/Quiz Details` route regardless of the current screen.
3. A slight delay is used to ensure the Navigator is ready if the app was cold-booted.

## 5. State Management
For this phase, the app primarily uses:
- **StatefulWidgets:** For screen-level local state (e.g., current question index, form inputs).
- **Global Variables:** `lib/utils/global.dart` holds app-wide constants (colors) and temporary session data (current user profile).
- **Streams:** `StreamBuilder` is heavily used to provide real-time updates for quiz lists and attempt history.

## 6. Security Implementation
- **Firestore Rules:** Enforce that only the `creatorId` can modify a quiz.
- **Email Verification:** A guard in the `main.dart` router or splash screen ensures `FirebaseAuth.instance.currentUser?.emailVerified` is true before allowing access to `/home`.
- **Admin Role:** The `AdminService` checks for a boolean flag or role string in the user's Firestore document to grant elevated UI access.
