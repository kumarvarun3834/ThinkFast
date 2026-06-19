# ThinkFast 🚀

ThinkFast is a high-performance, feature-rich quiz platform built with Flutter and Firebase. It's designed to provide a seamless experience for both quiz creators and participants, with a focus on real-time synchronization, security, and AI-driven personalization.

## ✨ Key Features

### 🛠️ For Creators
*   **Dynamic Quiz Creation**: Build complex quizzes with multiple-choice questions, custom timers, and descriptions.
*   **Attempt Limits**: Implement "Select N out of M" logic with global or module-specific constraints for each question type.
*   **Quiz Locking**: Instantly stop new responses while keeping your quiz public and visible.
*   **Attempt Management**: Toggle between single or multiple attempts to control user interaction.
*   **Creator Analytics**: View detailed response logs, sorted by attempt number and User ID for precise insights.
*   **Visibility Control**: Easily switch quizzes between Public and Private modes.

### 🎓 For Participants
*   **My Attempts**: Track personal growth with a detailed history of scores and performance across all quizzes.
*   **Enhanced Review Mode**: Deep-dive into results with color-coded navigators, solution explanations, and tagged correct/incorrect choices.
*   **AI Personalization**: Deeply customizable profiles for goal tracking, learning interests, and AI-driven recommendations.
*   **Active Session Protection**: Smart auto-expiry and cleanup system prevents multiple simultaneous attempts and handles glitches gracefully.
*   **Real-time Results**: Instant score calculation based on customizable marking schemes and detailed answer review.

### 🛡️ Under the Hood
*   **Modular Architecture**: Specialized services for Users, Quizzes, Attempts, Analytics, and Notifications.
*   **Secure Firestore Backend**: Production-grade security rules protecting private data and answer keys.
*   **Dual-Layer Admin System**: Global application administrators and delegated quiz-specific managers.
*   **Comprehensive Logging**: Audit logs and generation history for platform-wide activity tracking.

## 🚀 Tech Stack

*   **Frontend**: Flutter (Dart)
*   **Backend**: Firebase (Firestore, Authentication)
*   **State Management**: Stateful Widgets & Global Utilities
*   **Typography**: Google Fonts (Poppins)

## 📦 Getting Started

### Prerequisites
*   Flutter SDK (`^3.8.1`)
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
