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
- **Session Management:** Secure logout and persistence using Firebase Auth.

### 3.2 Quiz Creation & Management
- **Quiz Editor:** A comprehensive form to define quiz title, description, visibility (public/private), time limits, and marking schemes.
- **Question Types:** Support for multiple-choice questions with configurable options.
- **Idempotency & Rate Limiting:** Prevents duplicate quiz creation and limits how often a user can create new quizzes to prevent spam.
- **Answer Keys:** Separate management of answer keys to ensure integrity during the quiz.
- **My Quizzes:** A dedicated space for creators to manage their content, including editing and (soft) deleting.
- **Participant Response Analytics:** Creators can view a list of all participants, their scores, and specific attempt details (which answers they got right/wrong).

### 3.3 Quiz Participation
- **Joining Quizzes:** Users can join quizzes via a unique Quiz ID or through deep links (`/quiz?id=...`).
- **Real-time Quiz Experience:** A countdown-based quiz interface where users answer questions within the allotted time.
- **Attempt Tracking:** Users can view their history of quiz attempts and results.
- **Scoring:** Automated scoring based on the quiz's marking scheme.

### 3.4 AI Integration
- **AI Quiz Generation:** Leverage AI to generate quiz questions based on user prompts.
- **Usage Quotas:** Tracking AI usage per user to manage costs and prevent abuse.

### 3.5 Admin & Moderation
- **Admin Panel:** A restricted area for designated administrators to manage platform settings.
- **Feature Flags:** Ability to toggle features like quiz creation globally.
- **Admin Mode:** Registered admins can toggle "Admin Mode" to access elevated privileges or view the app from a user perspective.
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
