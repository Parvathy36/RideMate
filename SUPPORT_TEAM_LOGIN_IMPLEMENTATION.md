# Support Team Dashboard Implementation

## Overview
This implementation adds support for routing users with `userType: 'support team'` to a dedicated Support Team dashboard upon login.

## Changes Made

### 1. Updated Login Page (`lib/login_page.dart`)
- Added import for `screens/support_dashboard.dart`
- Added new case in the user type switch statement for 'support team'
- When a user with userType 'support team' logs in, they will be redirected to the SupportDashboard

### 2. Navigation Logic
The login flow now handles the following user types:
- **admin**: Redirects to AdminPage
- **support team**: Redirects to SupportDashboard  
- **driver**: Redirects to DriverDashboard (if approved) or DriverWaitingPage (if not approved)
- **user** (default): Redirects to HomePage

## How It Works

1. User logs in via email/password or Google Sign-In
2. After successful authentication, `_navigateBasedOnUserType()` is called
3. The function retrieves the user's `userType` from Firestore
4. Based on the userType, the user is redirected to the appropriate dashboard
5. Support team members are redirected to the existing SupportDashboard

## Prerequisites

- Users must have `userType: 'support team'` in their Firestore document
- The SupportDashboard widget must exist at `lib/screens/support_dashboard.dart`
- Admin users can create support team accounts through the Admin panel

## Testing

To test this functionality:
1. Create a support team user through the Admin panel
2. Log in with the support team user credentials
3. Verify that the user is redirected to the SupportDashboard
4. Ensure other user types still work correctly (admin, driver, regular users)

## Files Modified
- `lib/login_page.dart` - Added support team routing logic

## Files Referenced
- `lib/screens/support_dashboard.dart` - Existing support dashboard implementation