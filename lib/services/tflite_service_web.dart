import 'tflite_service_interface.dart';
import '../utils/nlp_processor.dart';

/// Stub implementation of TFLiteService for web platform
class TFLiteService implements TFLiteServiceInterface {
  @override
  bool get isModelLoaded => false;

  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  @override
  Future<void> initialize() async {
    print('ℹ️ TFLite is not supported on Web. Falling back to keyword matching.');
  }

  @override
  Future<ProcessedIntent> predictIntent(String text) async {
    // Always fallback to keyword matching on web
    return NLPProcessor.processMessage(text);
  }

  @override
  void dispose() {}
}
