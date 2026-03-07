import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'tflite_service_interface.dart';
import '../utils/nlp_processor.dart';

/// Native implementation of TFLiteService using tflite_flutter
class TFLiteService implements TFLiteServiceInterface {
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isModelLoaded = false;

  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  @override
  bool get isModelLoaded => _isModelLoaded;

  @override
  Future<void> initialize() async {
    if (_isModelLoaded) return;

    try {
      // Load labels
      final labelsData = await rootBundle.loadString('lib/assets/labels.txt');
      _labels = labelsData.split('\n').where((s) => s.isNotEmpty).toList();

      // Load model
      try {
        _interpreter = await Interpreter.fromAsset('assets/intent_model.tflite');
        _isModelLoaded = true;
        print('✅ TFLite Model loaded successfully');
      } catch (e) {
        print('⚠️ Could not load TFLite model from assets: $e');
        print('ℹ️ Falling back to simulated NLP inference for demonstration');
        _isModelLoaded = false;
      }
    } catch (e) {
      print('❌ Error initializing TFLiteService: $e');
    }
  }

  @override
  Future<ProcessedIntent> predictIntent(String text) async {
    if (!_isModelLoaded || _interpreter == null) {
      return NLPProcessor.processMessage(text);
    }

    try {
      final input = _preprocessText(text);
      var output = List<double>.filled(_labels!.length, 0).reshape([1, _labels!.length]);

      _interpreter!.run(input, output);

      List<double> probabilities = List<double>.from(output[0]);
      int bestIndex = 0;
      double maxProb = -1.0;

      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          bestIndex = i;
        }
      }

      String detectedIntent = _labels![bestIndex];
      
      return ProcessedIntent(
        intent: detectedIntent,
        confidence: maxProb,
        entities: NLPProcessor.extractEntities(text),
        suggestedAction: NLPProcessor.getSuggestedAction(detectedIntent),
      );
    } catch (e) {
      print('❌ Error during TFLite inference: $e');
      return NLPProcessor.processMessage(text);
    }
  }

  List<List<double>> _preprocessText(String text) {
    return [List<double>.filled(50, 0.0)];
  }

  @override
  void dispose() {
    _interpreter?.close();
  }
}
