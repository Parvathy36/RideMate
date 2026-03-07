"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendSupportWelcomeEmailOnCreate = exports.sendSupportWelcomeEmail = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
admin.initializeApp();
// Configure the email transport using the default SMTP transport and a GMail account.
// For Gmail, enable these:
// 1. Enable "Less secure app access" in your Google account settings (not recommended for production)
// Or use OAuth2 or App Passwords
const gmailEmail = functions.config().gmail.email;
const gmailPassword = functions.config().gmail.password;
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: gmailEmail,
        pass: gmailPassword,
    },
});
exports.sendSupportWelcomeEmail = functions.https.onCall(async (data, context) => {
    // Ensure the user is authenticated as an admin
    if (!context.auth || context.auth.token.role !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Must be an admin to send emails.');
    }
    const { email, password } = data;
    // Validate data
    if (!email || !password) {
        throw new functions.https.HttpsError('invalid-argument', 'Email and password are required.');
    }
    const mailOptions = {
        from: `"RideMate Support Team" <${gmailEmail}>`,
        to: email,
        subject: 'Welcome to RideMate Support Team',
        text: `Welcome to RideMate Support Team. Your account has been created successfully. Your login password is: ${password}. Please use this password to log in to your account.`,
        html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #6200EA;">Welcome to RideMate Support Team</h2>
        <p>Your account has been created successfully.</p>
        <p><strong>Your login password is:</strong> ${password}</p>
        <p>Please use this password to log in to your account.</p>
        <hr style="margin: 20px 0; border: 0; border-top: 1px solid #eee;" />
        <p style="color: #666; font-size: 12px;">This is an automated message from RideMate. Please do not reply to this email.</p>
      </div>
    `,
    };
    try {
        await transporter.sendMail(mailOptions);
        console.log(`New welcome email sent to: ${email}`);
        return { success: true, message: 'Email sent successfully' };
    }
    catch (error) {
        console.error('Error sending email:', error);
        throw new functions.https.HttpsError('internal', 'Unable to send email. Please try again.');
    }
});
// Alternative: Trigger email when a new support team member is created in Firestore
exports.sendSupportWelcomeEmailOnCreate = functions.firestore
    .document('users/{userId}')
    .onCreate(async (snap, context) => {
    const userData = snap.data();
    // Only send email if the user is a support team member
    if (userData && userData.userType === 'support team') {
        const mailOptions = {
            from: `"RideMate Support Team" <${gmailEmail}>`,
            to: userData.email,
            subject: 'Welcome to RideMate Support Team',
            text: `Welcome to RideMate Support Team. Your account has been created successfully. Your login password is: ${userData.password || 'provided separately'}. Please use this password to log in to your account.`,
            html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #6200EA;">Welcome to RideMate Support Team</h2>
            <p>Your account has been created successfully.</p>
            <p><strong>Your login password is:</strong> ${userData.password || 'provided separately'}</p>
            <p>Please use this password to log in to your account.</p>
            <hr style="margin: 20px 0; border: 0; border-top: 1px solid #eee;" />
            <p style="color: #666; font-size: 12px;">This is an automated message from RideMate. Please do not reply to this email.</p>
          </div>
        `,
        };
        try {
            await transporter.sendMail(mailOptions);
            console.log(`Welcome email sent to new support team member: ${userData.email}`);
        }
        catch (error) {
            console.error('Error sending welcome email:', error);
        }
    }
});
//# sourceMappingURL=index.js.map