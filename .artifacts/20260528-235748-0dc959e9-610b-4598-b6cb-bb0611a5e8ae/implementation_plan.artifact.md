# Upgrade Project Dependencies and Build Tools

Upgrade Gradle, Android Gradle Plugin (AGP), and Kotlin to meet Flutter's requirements and resolve build errors.

## Proposed Changes

### Android Build Configuration

Upgrade Gradle, AGP, and Kotlin versions.

#### [gradle-wrapper.properties](file:///E:/code/ThinkFast/android/gradle/wrapper/gradle-wrapper.properties)

- Upgrade `distributionUrl` from `gradle-8.12-all.zip` to `gradle-8.14-all.zip`.

#### [settings.gradle.kts](file:///E:/code/ThinkFast/android/settings.gradle.kts)

- Upgrade `com.android.application` version from `8.7.3` to `8.11.1`.
- Upgrade `org.jetbrains.kotlin.android` version from `2.1.0` to `2.2.20`.

### Flutter Dependencies

Resolve the `google_fonts` build error.

#### [pubspec.yaml](file:///E:/code/ThinkFast/pubspec.yaml)

- Run `flutter pub upgrade` to resolve the `google_fonts` constant evaluation error.

## Verification Plan

### Automated Tests
- Run `flutter build apk` to verify the build completes successfully without warnings or errors.

### Manual Verification
- None required beyond successful build.
