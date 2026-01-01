# Login Screen Implementation Walkthrough

I have implemented the login screen with Firebase Authentication as requested. Here is a summary of the changes and how to verify them.

## Key Features Implemented

1.  **Firebase Integration**:

    -   Added `firebase_auth`, `google_sign_in`, `sign_in_with_apple`, and `firebase_core`.
    -   Configured Android build files to use the Google Services plugin.
    -   Added internet permission for Firebase connectivity.

2.  **Authentication Service (`AuthService`)**:

    -   **Email/Password**: Sign Up and Sign In.
    -   **Google Sign-In**: Native Google OAuth flow.
    -   **Apple Sign-In**: Native Apple ID flow.
    -   **Guest Login**: Anonymous authentication.

3.  **UI Components**:

    -   **LoginPage**: Cleaning, modern UI with "Welcome Back" header, input fields, and social login buttons.
    -   **RegisterPage**: User registration with Name, Email, and Password.
    -   **AuthWrapper**: Handles automatic navigation between Login and Home pages based on auth state.

4.  **Guest Restrictions**:
    -   Guest users can access **Home** and **Search**.
    -   Guest users are BLOCKED from **Record Trip** and **Contribute** tabs with a Snackbar message.
    -   A banner on the Dashboard informs guest users of their limited access.

## How to Test

### Prerequisites

-   Ensure `google-services.json` is in `android/app/` (You've already done this).
-   Ensure your Firebase Console has Email/Password, Google, and Apple providers enabled.
-   **For Google Sign-In**: You need to add the SHA-1 fingerprint of your debug keystore to the Firebase Console android app configuration.
    -   Command to get SHA-1: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android` (Linux/Mac).

### Testing Steps

1.  **Launch the App**:

    -   The app should start at the `LoginPage`.

2.  **Register a New User**:

    -   Click "Sign Up".
    -   Enter Name, Email, Password.
    -   Click "Sign Up". You should be redirected to the Home Page.
    -   Verify the greeting shows your Name.

3.  **Test Guest Login**:

    -   Sign Out (Icon in top right of Dashboard).
    -   Click "Continue as Guest".
    -   Verify you see the "You are using the app as a guest" banner.
    -   Try clicking "Record" tab. You should see a message: "Please sign in to access this feature".

4.  **Test Google/Apple Login** (If configured):
    -   Sign Out.
    -   Click "Continue with Google".
    -   Follow the native prompt.
    -   Verify you are logged in.

## Files Modified/Created

-   `pubspec.yaml`
-   `android/build.gradle.kts` & `android/app/build.gradle.kts`
-   `android/app/src/main/AndroidManifest.xml`
-   `lib/main.dart`
-   `lib/models/app_user.dart` (New)
-   `lib/services/auth_service.dart` (New)
-   `lib/services/providers.dart`
-   `lib/pages/login_page.dart` (New)
-   `lib/pages/register_page.dart` (New)
-   `lib/pages/home_page.dart`
