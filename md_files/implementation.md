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
- **Utilities:** `http` for AI API calls, `intl` for date formatting, `dart:developer` for large payload logging.

## 3. Service Layer Architecture
ThinkFast uses a **Facade Pattern** combined with **Domain Services**.

### 3.1 Domain Services
Located in `lib/services/`, these services handle specific collections or logic:
- `QuizService`: Manages the `quizzes`, `quiz_questions`, and `answer_keys` collections. Implements smart routing for updates (API for AI quizzes, Firestore for Manual).
- `UserService`: Manages user profiles and sensitive data in sub-collections.
- `AttemptService`: Handles scoring logic and orchestrates post-submission AI analysis.
- `AiService`: Manages AI backend communication, PDF multimodal processing, and privacy gating.
- `AdminService`: Handles audit logging and platform-wide staff configurations.

### 3.2 The Unified Database Service (`DatabaseService`)
Located in `lib/services/firebase_direct_commands.dart`, this class acts as a central hub. Instead of UI code interacting with multiple services, it calls `DatabaseService`, which coordinates the necessary domain services. This simplifies the UI-to-Logic interface.

## 4. Key Implementation Logic

### 4.1 Quiz Data Transformation
Quizzes are stored in a normalized way to optimize for quiz-taking performance and security:
- **Metadata** is stored in the `quizzes` collection.
- **Questions** (without answers) are stored in `quiz_questions`. Supports `explanation` as an alias for `description`.
- **Answers** are stored separately in `answer_keys` to prevent cheating.
- **Service-Level Enforcement:** `DatabaseService` proactively strips any answer data from question documents before they reach the UI layer.

### 4.2 Scoring Engine
Scoring is performed by the `AttemptService` and mirrored in the `ResultScreen` UI. It supports:
- **Single Choice:** Equality check on option IDs.
- **Multiple Choice:** Set-based comparison.
- **Integer:** Trimmed string comparison.
- **Marking Schemes:** Supports global, per-type, and per-question configurations.

### 4.3 Deep Link Routing
In `main.dart`, the `AppLinks` stream handles incoming URIs, extracting the quiz ID and navigating to the details screen using a global `navigatorKey`.

## 5. State Management
- **StatefulWidgets:** For screen-level local state.
- **Global Variables:** `lib/utils/global.dart` holds app-wide constants and cached profile data.
- **Streams:** `StreamBuilder` provides real-time updates for quiz feeds and attempt history.

## 6. Security & Privacy Implementation
- **AI Backend Orchestration**: All AI-related writes (Generation, Analysis) are offloaded to a secure server using an asynchronous worker pattern.
- **Security Payload Hardening**: Every AI request is bundled with a forced-refresh Firebase ID Token and an App Check attestation for origin verification.
- **Firestore Lockdown**: AI-generated quizzes and the `/explanation` hierarchy are write-locked for regular users.
- **Performance Optimization**: Uses `MemoizedFirestoreReader` for batched reads in `initAppData` and `fetchAggregatedQuizDetails` to reduce sequential Firestore calls.
- **Privacy Gating**: Advanced features and PII-heavy payloads are restricted based on the `optInAiAnalysis` (2nd Privacy Policy) status.
- **Safe Timestamping**: UI components parse timestamps using `DateTime.tryParse` to handle `Timestamp`, `DateTime`, or `String` variants safely.
- **Data Traces**: Large payloads are logged via `developer.log()` to bypass console truncation.
