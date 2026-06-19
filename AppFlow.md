# Application Flow - ThinkFast

## 1. Authentication Flow
The entry point of the application ensures that users are authenticated and verified before accessing core features.

1.  **Splash Screen:** The entry point where the app initializes Firebase and checks for **Maintenance Mode**.
    *   If **Maintenance Mode** is ON: Redirect to **Maintenance Screen**.
        *   Regular users see the maintenance message.
        *   Administrators see a "Bypass" button to enter the app.
    *   If **Maintenance Mode** is OFF:
        *   If **Not Logged In**: Redirect to **Login Screen**.
        *   If **Logged In but Not Verified**: Redirect to **Verification Screen**.
        *   If **Logged In and Verified**: Redirect to **Home Screen**.
3.  **Login/Signup:** Users can sign up with Email/Password or use Google Sign-In.
4.  **Verification:** A mandatory step where users must verify their email address. The screen includes an auto-check timer that reloads the user state every 4 seconds. Once verified, the user is redirected to the **Profile Screen**.

## 2. Creator Flow (Quiz Management)
Creators manage the lifecycle of a quiz from inception to analyzing results.

1.  **Home Screen:** Tap the "Create" button or navigate to "My Quizzes".
2.  **Quiz Editor (QuizPage):**
    *   Enter Quiz Metadata (Title, Description, Time, Visibility).
    *   Configure Marking Scheme (Global, Per-Type, or Per-Question).
    *   Set Attempt Limits ("Select N out of M") globally or per-module.
    *   Add/Edit Questions (Manual entry, AI-assisted, or JSON import).
3.  **Publishing:** Save the quiz to Firestore.
4.  **Management:**
    *   **Edit:** Modify existing quizzes.
    *   **Delete:** Soft delete quizzes to hide them from public view.
    *   **Responses:** Navigate to **Quiz Responses Screen** to see a list of participants, their scores, and individual attempt details.

## 3. Participant Flow (Quiz Taking)
Participants join quizzes and complete them within the set time limits.

1.  **Discovery:**
    *   **Public Quizzes:** Browse available quizzes on the Home Screen.
    *   **Quiz ID:** Enter a unique ID provided by a creator.
    *   **Deep Link:** Click a link (e.g., `thinkfast.app/quiz?id=...`) to open the app directly to a quiz.
2.  **Quiz Details:** View title, description, and rules before starting.
3.  **Quiz Experience (Questions Screen):**
    *   Countdown timer starts.
    *   Navigate through modules with the color-coded navigator (Blue: Seen, Green: Answered, Purple: Review).
    *   Observe attempt limits per section.
    *   Submit answers before the timer expires.
4.  **Result Screen:** View the final score summary. Tap **"SEE ATTEMPT DETAILS"** to enter Review Mode.
5.  **Review Mode:** Re-uses the Quiz module with tagged correct/incorrect options, solution explanations, and performance-based navigator colors (Green: Correct, Red: Wrong).
6.  **History:** Access **My Attempts** to view past performance and re-enter Review Mode for any previous attempt.

## 4. Admin Flow
Administrators have elevated access to maintain platform health.

1.  **Admin Panel:** Accessible only to users with the `admin` role.
2.  **Feature Flags:** Toggle global settings (e.g., enabling/disabling quiz creation).
3.  **Moderation:** View and restrict quizzes that violate policies.
4.  **Admin Mode:** Toggle "Admin Mode" to see the app as a regular user while retaining elevated permissions in the background.

## 5. Navigation Structure (Routes)

| Route Name | Screen Component | Purpose |
| :--- | :--- | :--- |
| `/` | `MySplash` | App initialization. |
| `/login` | `LoginScreen` | User authentication. |
| `/signup` | `SignupScreen` | User registration. |
| `/verify` | `VerificationScreen` | Email verification check. |
| `/home` | `Main_Screen` | Main dashboard & public quizzes. |
| `/My Quiz` | `Main_Screen` | Filtered view for creator's own quizzes. |
| `/Create Quiz` | `QuizPage` | Create a new quiz. |
| `/Update Quiz` | `QuizPage` | Edit an existing quiz. |
| `/Quiz` | `Quesations` | The active quiz session. |
| `/Quiz Result` | `ResultScreen` | Post-quiz summary. |
| `/Quiz Details` | `QuizDetailsScreen` | Pre-quiz landing page. |
| `/My Attempts` | `MyAttemptsScreen` | User's personal attempt history. |
| `/Quiz Responses` | `QuizResponsesScreen` | Detailed participant analytics for creators. |
| `/profile` | `ProfileScreen` | User account management. |
| `/Admin Panel` | `AdminPanel` | Platform administration. |
| `/maintenance` | `MaintenanceScreen` | Global maintenance landing page. |
