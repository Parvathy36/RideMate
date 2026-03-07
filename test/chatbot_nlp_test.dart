import 'package:flutter_test/flutter_test.dart';
import 'package:ridemate/services/tflite_service.dart';
import 'package:ridemate/utils/nlp_processor.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chatbot NLP Integration Tests', () {
    late TFLiteService tfliteService;

    setUp(() {
      tfliteService = TFLiteService();
    });

    test('TFLiteService Fallback to Keywords when model missing', () async {
      // Since we don't have the real .tflite file in the test environment,
      // it should fallback to the keyword-based NLPProcessor.
      await tfliteService.initialize();
      
      final result = await tfliteService.predictIntent('how to book a ride');
      
      expect(result.intent, equals('ride_booking_help'));
      expect(result.confidence, greaterThan(0.0));
    });

    test('NLPProcessor Entity Extraction', () {
      final text = 'I want to report an issue with ride ABC12345 and I was charged 500 rupees';
      final entities = NLPProcessor.extractEntities(text);
      
      expect(entities['ride_ids'], contains('ABC12345'));
      expect(entities['amounts'], contains(500.0));
    });

    test('NLPProcessor Intent Detection (Keyword-based)', () {
      final text = 'payment failed for my last ride';
      final result = NLPProcessor.processMessage(text);
      
      expect(result.intent, equals('payment_failed'));
      expect(result.suggestedAction, equals('troubleshoot_payment'));
    });
  });
}
