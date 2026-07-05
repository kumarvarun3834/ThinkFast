# ThinkFast 🚀

ThinkFast is a high-performance, feature-rich quiz platform built with Flutter and Firebase. It's designed to provide a seamless experience for both quiz creators and participants, with a focus on real-time synchronization, security, and AI-driven personalization.

## ✨ Key Features

### 🛠️ For Creators & Managers
*   **Dynamic Quiz Creation**: Build complex quizzes with multiple-choice questions, custom timers, and descriptions.
*   **Delegated Management (QAdmins)**: Add collaborators with granular permissions to help manage questions, view results, or moderate participants.
*   **Attempt Limits & Logic**: Implement "Select N out of M" logic with global or module-specific constraints.
*   **Flexible Timing**: Set global, per-question, or individual override timers (0 for unlimited).
*   **Session Control**: Instantly lock or unlock quiz sessions to control response windows.
*   **Advanced Analytics**: View detailed response logs, sorted by attempt number and User ID for precise insights.
*   **Visibility Control**: Easily switch quizzes between Public, Private, and Protected (Restricted) modes.

### 🎓 For Participants
*   **Growth Tracking**: Personal attempt history with detailed scores and performance trends across all quizzes.
*   **Enhanced Review Mode**: Deep-dive into results with color-coded navigators, solution explanations, and correct/incorrect tagging.
*   **AI-Driven Personalization**: Customizable profiles for goal tracking, learning styles, and personalized recommendations.
*   **Active Session Protection**: Smart auto-expiry and cleanup system prevents multiple simultaneous attempts and handles glitches gracefully.
*   **Real-time Results**: Instant score calculation based on customizable marking schemes and detailed answer review.

### 🛡️ Administrative Suite (App Admins)
*   **Centralized Admin Panel**: Master control for platform settings, feature flags, and system-wide maintenance mode.
*   **User Management**: Deep inspection of user profiles, statistics synchronization, and account lifecycle management.
*   **Audit Logging**: Comprehensive system logs tracking all administrative actions (Who, What, When, and Target).
*   **Feature Flagging**: Toggle critical platform features (AI, Take Quiz, Registrations, etc.) in real-time without redeployment.

## 🏗️ Architecture & Security
*   **Modular Service Layer**: Specialized services for Users, Quizzes, Attempts, Analytics, and Notifications.
*   **Dual-Layer Permissions**: Hierarchical access control combining global App Admin roles and quiz-specific delegated permissions.
*   **Secure Firestore Backend**: Production-grade security rules protecting private data, answer keys, and administrative operations.
*   **Data Integrity**: Automated background sync, 7-day auto-purge for unverified accounts, and IP-based brute-force protection.

## 🚀 Tech Stack

*   **Frontend**: Flutter (Dart)
*   **State Management**: Reactive Streams (RxDart)
*   **Local Caching**: Shared Preferences (Last 10 Quizzes)
*   **Backend**: Firebase (Firestore, Authentication, Storage)
*   **Security**: IPify (Public IP Detection)
*   **Typography**: Google Fonts (Poppins)

## 📦 Getting Started

### Prerequisites
*   Flutter SDK (`^3.10.0`)
*   Firebase Project Setup

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/yourusername/ThinkFast.git
    cd ThinkFast
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration**:
    *   Initialize Firebase using `flutterfire configure`.
    *   Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are correctly placed.

4.  **Run the application**:
    ```bash
    flutter run
    ```

## 📜 License

© 2024 ThinkFast. Developed for advanced learning and quiz management.
