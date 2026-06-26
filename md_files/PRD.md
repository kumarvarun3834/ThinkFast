# Product Requirements Document (PRD) - ThinkFast

## 1. Product Overview
**ThinkFast** is a dynamic, mobile-first quiz platform that allows users to create, share, and participate in quizzes. It aims to provide a seamless experience for both educators/content creators and learners by leveraging real-time database capabilities and AI-assisted content generation.

## 2. Target Audience
- **Students/Learners:** Individuals looking to test their knowledge or practice for exams.
- **Educators/Trainers:** People who want to create assessments or interactive learning sessions.
- **Casual Users:** People looking for fun trivia or social quizzes.

## 3. Key Features

### 3.1 Authentication & User Management
- **Multi-method Login:** Support for Email/Password and Google Sign-In.
- **Email Verification:** Mandatory email verification for accessing core features like quiz creation and participation.
- **User Profiles:** Users can manage their display name and profile picture (synced from Google or custom).
- **Session Management:** Secure logout and persistence using Firebase Auth. Includes active session protection to prevent simultaneous quizzes, with a "Double Tap to Bypass" mechanism for clearing stuck or unexpired sessions.

### 3.2 Quiz Creation & Management
- **Quiz Editor:** A comprehensive form to define quiz title, description, visibility (public/private), time limits, and marking schemes.
- **Attempt Limits (Select N out of M):** Creators can limit the number of questions a participant can attempt per section or question type, mimicking competitive exam environments.
- **Flexible Timing:** Support for total quiz duration (0 for unlimited), generalized per-question timers, and specific individual question overrides.
- **Quiz Scheduling:** Creators can set a specific date and time for a quiz to become active for responses.
- **Restricted Quizzes:** Ability to restrict quiz attempts to a specific list of User UIDs. Support for dynamic participant access, allowing owners to grant attempt rights to specific users manually.
- **Managed Quizzes & Collaborators:** Owners can add managers to quizzes to help monitor responses and moderate participants. Dedicated screens for team management and permission configuration.
- **Question Types:** Support for Single Choice, Multiple Choice, and Integer questions with configurable options and solution descriptions.
- **Recycle Bin (Soft Delete):** Quizzes and attempts are soft-deleted and can be recovered within a 7-day window. Owners can manage their trash via the Recycle Bin.
- **Bulk Moderation:** Support for multiple selection via long-press to perform batch unblocking, response recovery, or soft-deletion.
- **Idempotency & Rate Limiting:** Prevents duplicate quiz creation and limits how often a user can create new quizzes to prevent spam.
- **Answer Keys:** Separate management of answer keys and solution explanations to ensure integrity during the quiz.
- **My Quizzes:** A dedicated space for creators to manage their content, including editing and (soft) deleting.
- **Participant Response Analytics:** Creators can view a list of all participants, their scores, and specific attempt details. The system also tracks aggregate performance metrics for each question and overall quiz statistics.

### 3.3 Quiz Participation
- **Joining Quizzes:** Users can join quizzes via a unique Quiz ID or through deep links (`/quiz?id=...`).
- **Real-time Quiz Experience:** A countdown-based quiz interface with immersive UI. Includes a color-coded navigator that reflects the status (Seen, Answered, Marked for Review, Correct, Wrong).
- **Attempt Tracking:** Users can view their history of quiz attempts and results.
- **Detailed Review Mode:** After completion, users can review each question with highlighted correct answers, their own choices, and detailed solution explanations.
- **Scoring:** Automated scoring based on the quiz's marking scheme.

### 3.4 AI Integration
- **AI Quiz Generation:** Leverage AI to generate quiz questions based on user prompts.
- **Usage Quotas:** Tracking AI usage per user to manage costs and prevent abuse.

### 3.5 Admin & Moderation
- **Admin Panel:** A restricted area for designated administrators to manage platform settings.
- **Feature Flags:** Ability to toggle features like quiz creation globally.
- **Admin Mode:** Registered admins can toggle "Admin Mode" to access elevated privileges or view the app from a user perspective.
- **Collective Admin Management:** Support for bulk-updating permissions (Grant/Revoke/Set) for multiple administrators.
- **Rate-Limited Data Refresh:** UI safeguards and permissions to control manual data fetching from Firestore, optimizing resource usage.
- **Optimized Permission Caching:** Client-side caching of administrative privileges to reduce redundant database calls.
- **Moderation:** Tools to restrict or delete quizzes that violate platform policies.
- **Audit Logs:** Logging of administrative actions for transparency and security.

## 4. Technical Stack
- **Frontend:** Flutter (Dart)
- **UI/UX:** Google Fonts (Poppins), Custom Dark Theme
- **Backend/Database:** Firebase Firestore
- **Authentication:** Firebase Authentication
- **Storage:** Firebase Storage (for profile photos)
- **Deep Linking:** `app_links` package
- **Analytics:** Firebase Analytics

## 5. User Flow

### 5.1 Creator Flow
1. Login/Signup -> Verify Email.
2. Navigate to "Create New Quiz".
3. Enter Quiz details and Questions (or use AI generation).
4. Save and Publish.
5. Share Quiz ID or Deep Link with participants.

### 5.2 Participant Flow
1. Login/Signup -> Verify Email.
2. Enter Quiz ID or click a Deep Link.
3. View Quiz Details and Start Quiz.
4. Complete Questions within time limit.
5. View Results and Attempt History.

## 6. Future Enhancements
- **Leaderboards:** Public leaderboards for popular quizzes.
- **Rich Media Support:** Including images and videos in quiz questions.
- **Real-time Multiplayer:** Synchronized quiz sessions for live classrooms.
- **Exporting Results:** Allow creators to export participant responses to CSV/PDF.
- **Advanced AI:** AI-powered feedback on quiz performance for participants.
