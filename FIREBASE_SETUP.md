# Firebase Setup Guide for RideMate

## Prerequisites
1. Install Flutter CLI
2. Install Firebase CLI: `npm install -g firebase-tools`
3. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`

## Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `ridemate` (or your preferred name)
4. Enable Google Analytics (optional)
5. Click "Create project"

## Step 2: Enable Authentication
1. In Firebase Console, go to "Authentication"
2. Click "Get started"
3. Go to "Sign-in method" tab
4. Enable "Email/Password" provider
5. Click "Save"

## Step 3: Enable Firestore Database
1. In Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (for development)
4. Select a location close to your users
5. Click "Done"

## Step 4: Configure Flutter App
1. Login to Firebase CLI:
   ```bash
   firebase login
   ```

2. Configure FlutterFire:
   ```bash
   cd d:\ridemate
   flutterfire configure
   ```
   - Select your Firebase project
   - Select platforms you want to support (Android, iOS, Web, etc.)
   - This will automatically generate `firebase_options.dart` with your actual configuration

## Step 5: Update Dependencies
Run the following command to get all dependencies:
```bash
flutter pub get
```

## Step 6: Test the App
1. Run the app:
   ```bash
   flutter run
   ```

2. Test the authentication flow:
   - Try registering a new account
   - Try logging in with the created account
   - Test the logout functionality

## Security Rules (Optional)
For production, update Firestore security rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read and write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Troubleshooting
1. If you get "Firebase not initialized" error, make sure Firebase.initializeApp() is called before runApp()
2. If authentication doesn't work, check that Email/Password provider is enabled in Firebase Console
3. For web deployment, make sure to configure hosting in Firebase Console

## Next Steps
- Add more authentication providers (Google, Facebook, etc.)
- Implement user profile management
- Add ride booking functionality
- Set up push notifications
- Deploy to app stores