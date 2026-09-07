# Account Deletion System Implementation Plan

This plan outlines the implementation of a secure account deletion system for ThinkFast. Deleting an account will permanently remove the user's authentication and all associated Firestore data (profile, private details, and attempt history).

## User Review Required

> [!CAUTION]
> Account deletion is irreversible. All quiz attempt history and personalization data will be lost.
> Authentication providers (Firebase Auth) require a recent login to delete an account. Users may be prompted to re-login before final deletion.

## Proposed Changes

### [Authentication & Services]

#### [MODIFY] [auth_service.dart](file:///G:/code/ThinkFast/lib/auth/auth_service.dart)
- Add `deleteAccount()` method to handle the recursive deletion of Auth and database records.

#### [MODIFY] [user_service.dart](file:///G:/code/ThinkFast/lib/services/user_service.dart)
- Add `purgeUserData()` method to handle the deletion of Firestore documents:
    - `/users/{uid}`
    - `/users/{uid}/private/details`
    - `/users/{uid}/protected/details`
    - `/devices/{uid}`
    - `/user_usage/{uid}`
    - `/responses` (filtered by `userId`)

---

### [UI Components]

#### [MODIFY] [profile_screen.dart](file:///G:/code/ThinkFast/lib/screens/profile/profile_screen.dart)
- Add a "Delete Account" button in the Profile settings.
- Implement a double-confirmation dialog with an optional password verification for security.

## Verification Plan

### Manual Verification
1. Log in with a test account.
2. Complete a few quizzes to generate attempt history.
3. Navigate to Profile > Delete Account.
4. Confirm deletion (verify the password prompt if applicable).
5. Verify in Firebase Console:
    - User is removed from Authentication.
    - All associated documents in `users`, `devices`, and `responses` are deleted.
6. Attempt to log in again with the same credentials (should fail).
