# Firebase Authentication Troubleshooting Guide

## Issues Fixed:
1. ✅ Moved `google-services.json` to correct location (`android/app/`)
2. ✅ Added Internet permissions to AndroidManifest.xml
3. ✅ Added Google Services plugin to Android build files
4. ✅ Fixed package name mismatch (changed to `ride.mate`)
5. ✅ Added Firebase SDK to web/index.html
6. ✅ Enhanced error handling in AuthService
7. ✅ Added Firebase connection test

## Firebase Console Checklist:

### 1. Authentication Setup
- [ ] Go to Firebase Console: https://console.firebase.google.com/
- [ ] Select your project: `ridemate-afd1e`
- [ ] Navigate to **Authentication** > **Sign-in method**
- [ ] Ensure **Email/Password** provider is **ENABLED**
- [ ] If not enabled, click on Email/Password and toggle it ON

### 2. Project Configuration
- [ ] Go to **Project Settings** (gear icon)
- [ ] Under **General** tab, verify:
  - Project ID: `ridemate-afd1e`
  - Project number: `975273579439`

### 3. App Registration
- [ ] In **Project Settings** > **General** > **Your apps**
- [ ] Verify Android app is registered with package name: `ride.mate`
- [ ] Verify Web app is registered
- [ ] Verify iOS app is registered (if using iOS)

### 4. Firestore Database
- [ ] Go to **Firestore Database**
- [ ] Ensure database is created
- [ ] Check security rules (should allow authenticated users)

### 5. API Keys and Restrictions
- [ ] Go to **Project Settings** > **General**
- [ ] Check that API keys are not restricted for development
- [ ] For production, properly configure API key restrictions

## Common Error Solutions:

### Error: "operation-not-allowed"
**Solution:** Enable Email/Password authentication in Firebase Console
1. Firebase Console > Authentication > Sign-in method
2. Click on Email/Password
3. Enable the first toggle (Email/Password)
4. Save

### Error: "app-not-authorized" or "invalid-api-key"
**Solution:** Check Firebase configuration
1. Verify API keys in `firebase_options.dart` match Firebase Console
2. Ensure package names match between `google-services.json` and `build.gradle`
3. Re-download configuration files if needed

### Error: "network-request-failed"
**Solution:** Check internet connectivity and permissions
1. Ensure device/emulator has internet access
2. Verify INTERNET permission in AndroidManifest.xml (already added)
3. Check if corporate firewall is blocking Firebase domains

### Error: "internal-error"
**Solution:** Usually a temporary Firebase issue
1. Wait a few minutes and try again
2. Check Firebase Status: https://status.firebase.google.com/
3. Verify all configuration files are in correct locations

## Testing Steps:

1. **Run the app and check console logs** for Firebase connection test results
2. **Try registering a new user** with a valid email and strong password
3. **Check Firebase Console > Authentication > Users** to see if user was created
4. **Check console logs** for detailed error messages

## If Issues Persist:

1. **Clean and rebuild the project:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Verify Firebase project status:**
   - Check if billing is enabled (required for some features)
   - Verify project is not suspended or restricted

3. **Check network connectivity:**
   - Try on different network
   - Disable VPN if using one
   - Check corporate firewall settings

4. **Re-generate configuration files:**
   - Download fresh `google-services.json` from Firebase Console
   - Re-run `flutterfire configure` command

## Debug Information:
- Package Name: `ride.mate`
- Project ID: `ridemate-afd1e`
- Firebase SDK versions in pubspec.yaml:
  - firebase_core: ^3.6.0
  - firebase_auth: ^5.3.1
  - cloud_firestore: ^5.4.3