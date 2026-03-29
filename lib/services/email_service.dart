import 'dart:math';

class EmailService {
  /// Generates a random 4-digit OTP
  static String generateOTP() {
    final random = Random();
    final otp = 1000 + random.nextInt(9000); // Generates a number between 1000 and 9999
    return otp.toString();
  }

  /// Sends an OTP email to the user
  /// Currently implemented as a mock/console log.
  /// Integration with services like SendGrid or Mailer can be added here.
  static Future<void> sendOtpEmail(String email, String otp) async {
    try {
      print('📧 Sending OTP Email to: $email');
      print('🔢 OTP Code: $otp');
      print('📝 Message: Your RideMate confirmation code is $otp. Please share this with your driver to start the ride.');
      
      // In a real application, you would use an HTTP call to an email API
      // or a server-side function to send the actual email.
      // Example Placeholder:
      // await http.post(
      //   Uri.parse('https://your-email-api.com/send'),
      //   body: {'to': email, 'otp': otp},
      // );
      
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
      print('✅ Email sent successfully (Mock)');
    } catch (e) {
      print('❌ Error sending OTP email: $e');
    }
  }

  static Future<void> sendDriverAssignedEmail({
    required String toEmail,
    required String driverName,
    required String carModel,
    required String carNumber,
    required String pickupLocation,
    required String otp,
  }) async {
    try {
      print('📧 Sending Driver Assigned Email to: $toEmail');
      print('🚘 Driver: $driverName ($carModel - $carNumber)');
      print('📍 Pickup: $pickupLocation');
      print('🔢 OTP Code: $otp');
      print('📝 Message: Your ride is confirmed. Share this OTP with the driver.');

      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
      print('✅ Email sent successfully (Mock)');
    } catch (e) {
      print('❌ Error sending driver assigned email: $e');
    }
  }
}
