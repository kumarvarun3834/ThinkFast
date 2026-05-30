# Fix Google Sign-In and Email Login Flow

Implement Google Sign-In, fix the email/password login process, and resolve UI compilation errors.

## Proposed Changes

### 1. Auth Service Enhancement
Update [auth_service.dart](file:///E:/code/ThinkFast/lib/auth/auth_service.dart) to include Google Sign-In logic.

#### [auth_service.dart](file:///E:/code/ThinkFast/lib/auth/auth_service.dart)
- Add `GoogleSignIn` instance.
- Implement `signInWithGoogle()` method.
- Update error handling to be more descriptive.

### 2. Login Screen UI/UX
Update [login_screen.dart](file:///E:/code/ThinkFast/lib/auth/login_screen.dart) to support both Google and Email/Password login.

#### [login_screen.dart](file:///E:/code/ThinkFast/lib/auth/login_screen.dart)
- Fix the import path for `AuthService` (change from `../services/auth_service.dart` to `auth_service.dart`).
- Add a "Sign in with Google" button.
- Improve the layout and error reporting.

### 3. UI Fixes
Fix the compilation error in [drawer_data.dart](file:///E:/code/ThinkFast/lib/widgets/drawer_data.dart).

#### [drawer_data.dart](file:///E:/code/ThinkFast/lib/widgets/drawer_data.dart)
- Remove the call to the non-existent `refreshParent()` method.
- Update the Login tile to navigate to the login screen instead of trying to run a function.

### 4. Application Routes
Update [main.dart](file:///E:/code/ThinkFast/lib/main.dart) to ensure all authentication-related routes are correctly defined.

#### [main.dart](file:///E:/code/ThinkFast/lib/main.dart)
- Verify `/login`, `/signup`, and `/verify` routes.

## Verification Plan

### Automated Tests
- Run `flutter build apk --debug` to ensure all compilation errors are resolved.

### Manual Verification
- Verify that the Login screen displays both Email/Password fields and the Google Sign-In button.
- Verify that clicking "Login" in the Sidebar Drawer navigates to the Login screen.
