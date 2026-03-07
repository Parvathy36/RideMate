import '../utils/nlp_processor.dart';

/// Interface for TFLite service to handle platform-specific implementations
abstract class TFLiteServiceInterface {
  bool get isModelLoaded;
  Future<void> initialize();
  Future<ProcessedIntent> predictIntent(String text);
  void dispose();
}
