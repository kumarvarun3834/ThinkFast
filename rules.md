# Development Rules & Standards - ThinkFast

## 1. Architecture & Service Layer
- **Facade First:** UI components must NOT interact with domain-specific services (`QuizService`, `UserService`, etc.) directly. Always use the `DatabaseService` facade.
- **Service Independence:** Domain services should remain independent. If logic requires multiple services, handle it within `DatabaseService`.
- **Async Safety:** All database operations must be `async` and include appropriate `try-catch` blocks or propagate errors to be handled by the UI.
- **Permission Toggles:** All operations in `DatabaseService` must call `_ensurePermission` to respect global feature flags. Administrators bypass these toggles unless it's a critical safety block.

## 2. Security & Data Privacy
- **The "No-Answers-in-Questions" Rule:** Never store answer keys or correct values within the `quiz_questions` collection. Correct answers must reside in the `answer_keys` collection to prevent client-side inspection.
- **Integer Question Logic:** For integer-type questions, always use `.trim()` on both user input and the correct answer before comparison to avoid whitespace issues.
- **Verification Guard:** Core write features (Creating quizzes, submitting attempts) must be protected by an email verification check.
- **Private Data:** Sensitive user data (emails, active sessions) must be stored in the `private` or `protected` sub-collections of a user's document, never in the root user document.

## 3. UI & Design Standards
- **Theme Consistency:** Do not use hardcoded hex values in widgets. Use the constants defined in `lib/utils/global.dart` (`bgColor`, `primaryAccent`, `cardColor`, etc.).
- **Typography:** All text should use the `GoogleFonts.poppins()` style.
- **Responsiveness:** Wrap scrollable content in `SafeArea` and ensure layouts work on both standard and notch-bearing devices.
- **User Feedback:** Every asynchronous action (logging in, saving a quiz) must show a loading indicator or a `SnackBar` upon completion/failure.

## 4. Coding Style
- **Naming Conventions:**
    *   Classes: `PascalCase`
    *   Variables/Methods: `camelCase`
    *   Files: `snake_case.dart`
- **Documentation:** Every public method in a service class must have a `///` documentation comment explaining its purpose and parameters.
- **Refactoring:** If a UI widget exceeds 300 lines, extract sub-widgets into the `lib/widgets/` directory.

## 5. Firebase & Database
- **Batching:** Use `WriteBatch` for operations that involve multiple document updates (e.g., submitting an attempt which updates responses, user stats, and active quiz status).
- **Soft Deletes:** Quizzes should never be permanently deleted from Firestore. Use the `isDeleted: true` flag. Once soft-deleted, access is restricted for all regular users AND the owner; only App Administrators can access these quizzes.
- **Timestamping:** Every document must have `createdAt` and `updatedAt` fields using `FieldValue.serverTimestamp()`.

## 6. Admin & Moderation
- **Audit Logging:** Every administrative or significant creator action (delete quiz, change feature flag, login) must be logged via `AdminService.logAction`.
- **Admin Mode:** The UI should visually distinguish when "Admin Mode" is active (e.g., a badge or border) to prevent accidental administrative actions.
