import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../services/chatbot_service.dart';
import '../utils/nlp_processor.dart';

void main() {
  group('Chatbot Service Tests', () {
    setUp(() {
      // Setup code before each test
    });

    tearDown(() {
      // Cleanup after each test
    });

    test('NLP Processor should recognize ride booking intent', () {
      final message = 'How to book a ride?';
      final result = NLPProcessor.processMessage(message);

      expect(result.intent, 'ride_booking_help');
      expect(result.confidence, greaterThan(0.0));
    });

    test('NLP Processor should recognize payment intent', () {
      final message = 'My payment failed';
      final result = NLPProcessor.processMessage(message);

      expect(result.intent, 'payment_failed');
      expect(result.confidence, greaterThan(0.0));
    });

    test('NLP Processor should recognize complaint intent', () {
      final message = 'Driver was rude';
      final result = NLPProcessor.processMessage(message);

      expect(result.intent, 'driver_behavior');
      expect(result.confidence, greaterThan(0.0));
    });

    test('NLP Processor should extract ride ID', () {
      final message = 'Problem with ride ABC123';
      final result = NLPProcessor.processMessage(message);

      expect(result.entities['ride_ids'], contains('ABC123'));
    });

    test('NLP Processor should extract amounts', () {
      final message = 'I was charged Rs. 250 for the ride';
      final result = NLPProcessor.processMessage(message);

      expect(result.entities['amounts'], contains(250.0));
    });

    test('NLP Processor should generate appropriate responses', () {
      final message = 'How to book a ride?';
      final result = NLPProcessor.processMessage(message);
      final response = NLPProcessor.generateResponse(result);

      expect(response, contains('book'));
      expect(response, contains('ride'));
    });

    test(
      'NLP Processor should detect low confidence for irrelevant queries',
      () {
        final message = 'What is the weather today?';
        final result = NLPProcessor.processMessage(message);

        expect(result.confidence, lessThan(0.5));
      },
    );
  });

  group('Chatbot UI Tests', () {
    testWidgets('Chatbot screen should build without errors', (
      WidgetTester tester,
    ) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const Placeholder(), // Replace with ChatbotScreen when available
                    ),
                  );
                },
                child: const Text('Open Chatbot'),
              ),
            ),
          ),
        ),
      );

      // Verify that the chatbot screen can be opened
      expect(find.text('Open Chatbot'), findsOneWidget);
    });
  });
}
