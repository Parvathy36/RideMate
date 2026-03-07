# Support Team Account Creation Feature

## Overview
Added functionality to the Admin panel to create support team accounts with the following features:
- Create support team members with full name, email, phone number, and password
- Store user data in Firebase users collection with userType: "support team"
- Create authentication account using Firebase Authentication
- Send automated welcome email with login credentials

## Changes Made

### 1. Updated Admin Menu
- Added "Support Team" to the sidebar menu items
- Updated the switch statement to handle the new menu index (now at position 4)

### 2. New UI Components
- `_buildSupportTeamContent()` - Main content container for support team section
- `_buildCreateSupportTeamCard()` - Card with form for creating new support team members
- `_buildCreateSupportForm()` - Form with validation for name, email, phone, and password
- `_buildSupportTeamList()` - Displays existing support team members

### 3. Core Functionality
- `_createSupportTeamMember()` - Creates Firebase Auth account and Firestore user document
- `_sendWelcomeEmail()` - Handles email sending logic (simulated in this implementation)

## Technical Implementation

### User Creation Process
1. Admin enters full name, email, phone number, and password
2. Validation checks for all required fields
3. Creates Firebase Authentication account using `registerWithEmailAndPassword`
4. Updates Firestore user document with:
   - `userType: 'support team'`
   - Additional user information (name, email, phone, etc.)
   - Creation timestamp
   - Admin ID who created the account

### Email Notification
The system simulates sending an email with the following content:
```
Subject: Welcome to RideMate Support Team
Body: Your account has been created. Email: <email>. Password: <password>. Use this password to log in.
```

### Production Deployment Note
For production deployment, the email sending functionality would need to be implemented using:
1. Firebase Cloud Functions triggered on user creation
2. Integration with email services like SendGrid, Nodemailer, or SMTP providers
3. Example Cloud Function code is included in the implementation as a comment

## Security Considerations
- Support team accounts are created with `userType: 'support team'` in Firestore
- Admin access is required to create support team accounts
- Password strength validation is enforced (minimum 6 characters)

## Files Modified
- `lib/admin.dart` - Added support team functionality to admin panel

## Testing
The feature was tested successfully, with logs showing:
- Successful account creation
- Proper data storage in Firestore
- Email simulation working correctly
- Support team member listing functionality