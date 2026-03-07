import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Natural Language Processing utility for chatbot intent recognition
class NLPProcessor {
  // Predefined intents and their patterns
  static final Map<String, List<String>> _intentPatterns = {
    'ride_booking_help': [
      'how to book',
      'book a ride',
      'ride booking',
      'schedule ride',
      'request ride',
      'find driver',
      'get cab',
      'call taxi',
      'hail ride',
      'order ride'
    ],
    'ride_pooling_explanation': [
      'ride pooling',
      'shared ride',
      'pool ride',
      'group ride',
      'split fare',
      'cost sharing',
      'multiple passengers',
      'carpool'
    ],
    'ride_status_check': [
      'ride status',
      'where is my driver',
      'driver location',
      'track ride',
      'ride progress',
      'arrival time',
      'eta',
      'estimated time'
    ],
    'payment_failed': [
      'payment failed',
      'transaction failed',
      'payment declined',
      'card declined',
      'payment error',
      'charge failed',
      'unable to pay'
    ],
    'refund_status': [
      'refund status',
      'refund update',
      'money back',
      'cancelled ride refund',
      'payment refund',
      'when will i get refund'
    ],
    'payment_methods': [
      'payment methods',
      'payment options',
      'how to pay',
      'accepted payments',
      'card payment',
      'upi payment',
      'cash payment',
      'wallet payment'
    ],
    'ride_issues': [
      'ride problem',
      'bad experience',
      'complaint about ride',
      'late driver',
      'wrong route',
      'overcharged',
      'poor service',
      'ride quality'
    ],
    'driver_behavior': [
      'driver rude',
      'driver behavior',
      'rude driver',
      'driver complaint',
      'unsafe driving',
      'driver issue',
      'driver misconduct'
    ],
    'app_problems': [
      'app not working',
      'app issue',
      'app problem',
      'bug in app',
      'app crash',
      'app slow',
      'technical issue',
      'application error'
    ],
    'account_issues': [
      'account problem',
      'login issue',
      'sign in problem',
      'profile update',
      'account blocked',
      'verification issue',
      'phone number change'
    ],
    'general_help': [
      'help',
      'support',
      'customer service',
      'contact',
      'assistance',
      'need help',
      'what can you do'
    ],
    'driver_late': [
      'driver is late',
      'driver late arrival',
      'my driver has not arrived',
      'driver not here',
      'waiting for driver',
      'delayed driver',
      'where is my ride',
      'driver delayed'
    ],
    'lost_item': [
      'lost item',
      'forgot my phone',
      'left my wallet',
      'lost my bag',
      'forgot something',
      'lost property',
      'item left in ride',
      'forgot phone',
      'forgot wallet'
    ]
  };

  // Response templates for each intent
  static final Map<String, List<String>> _responseTemplates = {
    'ride_booking_help': [
      '''To book a ride:
1. Open the app and tap "Book Ride"
2. Enter pickup and destination locations
3. Select ride type (Solo/Pool)
4. Confirm booking and wait for driver match''',
      '''Booking a ride is simple! Just enter your pickup location, choose your destination, select ride type, and confirm. Your driver will arrive shortly!''',
      '''Here's how to book:
- Set pickup location
- Choose destination
- Pick ride type
- Confirm and wait for driver
Need help with any step?'''
    ],
    'ride_pooling_explanation': [
      '''Ride pooling lets you share rides with other passengers going the same way. Benefits:
- Lower fares (30-40% savings)
- Eco-friendly
- Meet new people
Just select "Pool" when booking!''',
      '''Ride pooling matches you with passengers traveling in the same direction. You'll share the ride and split the cost, saving money while reducing traffic!''',
      '''Pool rides connect you with other travelers on similar routes. You'll save up to 40% on fare costs while helping reduce carbon emissions. Win-win!'''
    ],
    'ride_status_check': [
      '''You can track your ride in real-time:
1. Open "My Rides" section
2. Tap on your active ride
3. View driver location and ETA
4. Call or message driver directly''',
      '''Check your ride status anytime in the "My Rides" section. You'll see live driver location, estimated arrival time, and can contact your driver directly.''',
      '''Track your ride progress in the app! Go to "My Rides", select your current trip, and you'll see live updates on driver location and arrival time.'''
    ],
    'payment_failed': [
      '''Payment failed? Try these solutions:
- Check card details are correct
- Ensure sufficient balance
- Try a different payment method
- Contact your bank if issue persists''',
      '''Don't worry about payment failures! Common fixes:
- Verify card information
- Check account balance
- Try alternative payment method
- Contact support if problem continues''',
      '''Payment issues? Here's what to do:
1. Double-check card details
2. Confirm adequate funds
3. Try another payment option
4. Reach out to us for assistance'''
    ],
    'refund_status': [
      '''Refunds typically process within 5-7 business days. Check status in:
1. "Payment History" section
2. Look for refund transaction
3. Contact support if delayed beyond 7 days''',
      '''Your refund is usually credited back within a week. You can monitor progress in "Payment History". If it's been longer, please contact our support team.''',
      '''Refund timeline: 5-7 business days. Track in "Payment History" section. If you haven't received it after a week, our support team can help investigate.'''
    ],
    'payment_methods': [
      '''We accept multiple payment methods:
- Credit/Debit Cards
- UPI Payments
- Wallets (Paytm, PhonePe)
- Cash (where available)
Choose your preferred method during booking!''',
      '''Payment options include:
- All major credit/debit cards
- UPI transfers
- Digital wallets
- Cash payment (driver discretion)
Select your favorite when confirming ride!''',
      '''Available payment methods:
- Credit/Debit cards
- UPI payments
- Mobile wallets
- Cash (where permitted)
You can set default payment method in app settings.'''
    ],
    'ride_issues': [
      '''Sorry about your ride experience! Please share details about:
- What went wrong?
- When did it happen?
- Ride ID or details
Our support team will investigate and assist you.''',
      '''We apologize for the poor experience. Could you tell us:
- What specifically happened?
- When was your ride?
- Any ride reference number?
We'll look into this immediately.''',
      '''That's concerning! Please provide:
1. Description of the issue
2. Date/time of incident
3. Ride details or ID
We take quality seriously and will address this promptly.'''
    ],
    'driver_behavior': [
      '''Driver behavior concerns are taken very seriously. Please report:
- Driver details
- Ride information
- Specific incidents
We'll investigate and take appropriate action.''',
      '''Thank you for reporting driver conduct issues. We need:
- Driver name/ID
- Ride details
- Description of behavior
Safety is our priority - we'll address this seriously.''',
      '''We're sorry you experienced this. Please share:
- Driver information
- Ride specifics
- Behavior details
We maintain strict standards and will investigate thoroughly.'''
    ],
    'app_problems': [
      '''Having app issues? Try these fixes:
- Force close and reopen app
- Clear app cache
- Update to latest version
- Reinstall if problems persist
Still having trouble?''',
      '''App problems? Quick solutions:
1. Close and restart the app
2. Clear cache in settings
3. Check for app updates
4. Reinstall if needed
Let us know if issues continue!''',
      '''Troubleshooting app issues:
- Restart the application
- Clear stored cache
- Install latest update
- Fresh install if necessary
Contact support for persistent problems.'''
    ],
    'account_issues': [
      '''Account problems? Common solutions:
- Reset password via email
- Update phone number in profile
- Complete email verification
- Contact support for login blocks''',
      '''For account issues:
- Forgot password? Use email reset
- Need to change phone? Update profile
- Verification pending? Check email
- Locked out? Contact our support team''',
      '''Account assistance:
1. Password reset through email
2. Profile updates in settings
3. Email verification completion
4. Support for access issues
What specific help do you need?'''
    ],
    'general_help': [
      '''I'm here to help! I can assist with:
- Ride booking and pooling
- Payment questions
- Customer support
- App issues
What do you need help with today?''',
      '''Hello! I can help you with:
- Booking rides and pool services
- Payment methods and refunds
- App troubleshooting
- General inquiries
What can I assist you with?''',
        '''Welcome to RideMate support! I can help with:
- Ride services
- Payments and billing
- App functionality
- Any questions you have
How may I help you today?'''
      ],
      'driver_late': [
        'I understand your driver is delayed. Could you please provide your Ride ID so I can look into this for you?'
      ],
      'lost_item': [
        'I\'m sorry to hear you lost an item. Could you please provide the Ride ID for that trip?'
      ]
    };

  /// Process user message and determine intent
  static ProcessedIntent processMessage(String message) {
    final normalizedMessage = message.toLowerCase().trim();
    
    // Find best matching intent
    String bestIntent = 'general_help';
    double highestScore = 0.0;
    Map<String, dynamic> extractedEntities = {};

    for (final entry in _intentPatterns.entries) {
      final intent = entry.key;
      final patterns = entry.value;
      
      double score = _calculateMatchScore(normalizedMessage, patterns);
      
      if (score > highestScore) {
        highestScore = score;
        bestIntent = intent;
      }
    }

    // Extract entities
    extractedEntities = extractEntities(normalizedMessage);

    // Determine confidence level
    final confidence = _calculateConfidence(highestScore, normalizedMessage.length);

    return ProcessedIntent(
      intent: bestIntent,
      confidence: confidence,
      entities: extractedEntities,
      suggestedAction: getSuggestedAction(bestIntent),
    );
  }

  /// Generate response based on intent
  static String generateResponse(ProcessedIntent intent) {
    final templates = _responseTemplates[intent.intent] ?? _responseTemplates['general_help']!;
    final randomIndex = DateTime.now().millisecondsSinceEpoch % templates.length;
    return templates[randomIndex];
  }

  /// Calculate match score between message and patterns
  static double _calculateMatchScore(String message, List<String> patterns) {
    double maxScore = 0.0;
    
    for (final pattern in patterns) {
      // Simple keyword matching with partial scoring
      if (message.contains(pattern)) {
        double score = pattern.length / message.length;
        if (score > maxScore) {
          maxScore = score;
        }
      }
    }
    
    return maxScore;
  }

  /// Extract entities from message
  static Map<String, dynamic> extractEntities(String message) {
    final entities = <String, dynamic>{};
    
    // Extract potential ride IDs (alphanumeric patterns)
    final rideIdRegex = RegExp(r'[A-Z0-9]{6,10}');
    final rideIds = rideIdRegex.allMatches(message)
        .map((match) => match.group(0))
        .where((id) => id != null)
        .cast<String>()
        .toList();
    
    if (rideIds.isNotEmpty) {
      entities['ride_ids'] = rideIds;
    }

    // Extract amounts
    final amountRegex = RegExp(r'(?:rs\.?|rupees?|₹)\s*(\d+(?:\.\d{1,2})?)|\b(\d+(?:\.\d{1,2})?)\s*(?:rs\.?|rupees?)\b', caseSensitive: false);
    final amounts = amountRegex.allMatches(message)
        .map((match) => match.group(1) ?? match.group(2))
        .where((amount) => amount != null)
        .cast<String>()
        .toList();

    if (amounts.isNotEmpty) {
      entities['amounts'] = amounts.map(double.tryParse).whereType<double>().toList();
    }

    return entities;
  }

  /// Calculate confidence level
  static double _calculateConfidence(double matchScore, int messageLength) {
    // Base confidence from pattern matching
    double confidence = matchScore;
    
    // Boost confidence for longer, more specific messages
    if (messageLength > 20) {
      confidence += 0.1;
    }
    
    // Cap at 1.0
    return confidence.clamp(0.0, 1.0);
  }

  /// Get suggested action based on intent
  static String getSuggestedAction(String intent) {
    final actionMap = {
      'ride_booking_help': 'show_booking_steps',
      'ride_pooling_explanation': 'explain_pooling',
      'ride_status_check': 'check_ride_status',
      'payment_failed': 'troubleshoot_payment',
      'refund_status': 'check_refund_status',
      'payment_methods': 'list_payment_options',
      'ride_issues': 'escalate_complaint',
      'driver_behavior': 'report_driver',
      'app_problems': 'troubleshoot_app',
      'account_issues': 'account_assistance',
      'general_help': 'provide_general_help',
      'driver_late': 'start_driver_late_flow',
      'lost_item': 'start_lost_item_flow',
    };
    
    return actionMap[intent] ?? 'unknown_action';
  }
}

/// Result of NLP processing
class ProcessedIntent {
  final String intent;
  final double confidence;
  final Map<String, dynamic> entities;
  final String suggestedAction;

  ProcessedIntent({
    required this.intent,
    required this.confidence,
    required this.entities,
    required this.suggestedAction,
  });
}