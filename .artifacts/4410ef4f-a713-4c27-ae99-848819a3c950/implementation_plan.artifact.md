# AI Wizard Reliability & Workflow Optimization

This plan addresses several logical and structural issues identified in the AI Quiz Wizard workflow, ensuring data integrity, security, and a smoother user experience.

## User Review Required

> [!IMPORTANT]
> - **Navigation Change**: The status screen will now use `pushReplacementNamed` when a quiz is completed. This means the user cannot press "Back" to return to the "Generation Completed" screen.
> - **Verification Gate**: Users will now be blocked from starting the AI Wizard if they haven't verified their email, rather than being blocked at the final generation step.

## Proposed Changes

### [Component: Logic & State]

#### [MODIFY] [user_connect.dart](file:///G:/code/ThinkFast/lib/services/firebase/user_connect.dart)
- Ensure `optInAiAnalysis` and profile data are fetched reliably to prevent "Access Denied" errors on starred items.

#### [MODIFY] [ai_service.dart](file:///G:/code/ThinkFast/lib/services/ai_service.dart)
- Implement client-side debouncing to prevent duplicate generation requests.
- Add a small delay/retry logic in `analyzeAttempt` to ensure Firestore responses are synced before backend lookup.

### [Component: UI & Routing]

#### [MODIFY] [ai_generation_status_screen.dart](file:///G:/code/ThinkFast/lib/screens/quiz/ai_generation_status_screen.dart)
- Fix the navigation stack by using `pushReplacementNamed` instead of `pushNamed` for the final quiz redirect.
- Map status strings (`queued`, `generating`, `validating`) to visual progress percentages (10%, 40%, 80%).

#### [MODIFY] [ai_quiz_generator.dart](file:///G:/code/ThinkFast/lib/screens/quiz/ai_quiz_generator.dart)
- Move the email verification check to the `initState` or the very first step.
- Update the "Starred ⭐" guard to handle cases where the profile might be null during initialization.

### [Component: Data Integrity]

#### [MODIFY] [quiz_data_processor.dart](file:///G:/code/ThinkFast/lib/services/quiz_data_processor.dart)
- Update `processImportData` to support `explanation` as an alias for `description` in question objects, ensuring solutions from AI are correctly imported.

## Verification Plan

### Automated Tests
- Import a JSON with `explanation` field and verify it appears as `description` in the Quiz Editor.
- Trigger AI generation and verify only one request is sent even if the button is tapped multiple times.

### Manual Verification
- Launch AI Wizard with an unverified account -> Verify immediate block.
- Complete AI generation -> Verify redirect to Details screen and check that "Back" goes to Home, not Status.
