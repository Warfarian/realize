import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'vision/vision_processor.dart';
import 'audio/audio_processor.dart';
import 'package:logging/logging.dart';

final _logger = Logger('MLService');

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  late final VisionProcessor _visionProcessor;
  late final AudioProcessor _audioProcessor;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _visionProcessor = VisionProcessor();
      _audioProcessor = AudioProcessor();

      await Future.wait([
        _visionProcessor.initialize(),
        _audioProcessor.initialize(),
      ]);

      _isInitialized = true;
    } catch (e) {
      _logger.severe('Error initializing ML Service: $e');
      rethrow;
    }
  }

  Future<ProcessingResult> processFrame(CameraImage frame) async {
    if (!_isInitialized) return ProcessingResult.empty();

    try {
      final detections = await _visionProcessor.processFrame(frame);
      return ProcessingResult(
        detections: detections,
        audioResult: null,
      );
    } catch (e) {
      _logger.severe('Error processing frame: $e');
      return ProcessingResult.empty();
    }
  }

  Future<ProcessingResult> processAudio(Float64List buffer) async {
    if (!_isInitialized) return ProcessingResult.empty();

    try {
      final audioResult = await _audioProcessor.processAudioBuffer(buffer);
      return ProcessingResult(
        detections: [],
        audioResult: audioResult,
      );
    } catch (e) {
      _logger.severe('Error processing audio: $e');
      return ProcessingResult.empty();
    }
  }

  void dispose() {
    _visionProcessor.dispose();
    _audioProcessor.dispose();
    _isInitialized = false;
  }
}

class ProcessingResult {
  final List<Detection> detections;
  final AudioAnalysisResult? audioResult;

  ProcessingResult({
    required this.detections,
    this.audioResult,
  });

  factory ProcessingResult.empty() {
    return ProcessingResult(
      detections: [],
      audioResult: AudioAnalysisResult.empty(),
    );
  }
}
