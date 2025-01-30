import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart' show Rect;

final _logger = Logger('VisionProcessor');

class VisionProcessor {
  static const int _inputSize = 300;
  static const int _numResults = 10;
  static const double _threshold = 0.5;
  
  Interpreter? _interpreter;
  List<String>? _labels;
  
  bool get isInitialized => _interpreter != null;
  
  Future<void> initialize() async {
    try {
      // Load model
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/ssd_mobilenet.tflite',
        options: options,
      );
      
      // Load labels
      _labels = await _loadLabels();
      
      _logger.info('Vision processor initialized successfully');
    } catch (e) {
      _logger.severe('Failed to initialize vision processor: $e');
      rethrow;
    }
  }

  Future<List<String>> _loadLabels() async {
    try {
      return [
        'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train',
        'truck', 'boat', 'traffic light', 'fire hydrant', 'stop sign',
        'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep',
        'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella',
        'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard',
        'sports ball', 'kite', 'baseball bat', 'baseball glove', 'skateboard',
        'surfboard', 'tennis racket', 'bottle', 'wine glass', 'cup', 'fork',
        'knife', 'spoon', 'bowl', 'banana', 'apple', 'sandwich', 'orange',
        'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair',
        'couch', 'potted plant', 'bed', 'dining table', 'toilet', 'tv',
        'laptop', 'mouse', 'remote', 'keyboard', 'cell phone', 'microwave',
        'oven', 'toaster', 'sink', 'refrigerator', 'book', 'clock', 'vase',
        'scissors', 'teddy bear', 'hair drier', 'toothbrush'
      ];
    } catch (e) {
      _logger.warning('Failed to load labels, using empty list: $e');
      return [];
    }
  }

  Future<List<Detection>> processFrame(CameraImage image) async {
    if (_interpreter == null) {
      _logger.warning('Interpreter not initialized');
      return [];
    }

    try {
      // Convert YUV420 to RGB
      final rgbImage = _convertYUV420ToRGB(image);
      
      // Resize image to match model input size
      final inputImage = img.copyResize(
        rgbImage,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear,
      );
      
      // Prepare input data
      final input = _imageToByteListFloat32(inputImage);
      
      // Prepare output arrays
      final outputLocations = List<List<double>>.filled(
        _numResults,
        List<double>.filled(4, 0.0),
      );
      final outputClasses = List<double>.filled(_numResults, 0);
      final outputScores = List<double>.filled(_numResults, 0);
      final numDetections = [0.0];

      // Run inference
      final outputs = {
        0: outputLocations,
        1: outputClasses,
        2: outputScores,
        3: numDetections,
      };
      
      _interpreter!.runForMultipleInputs([input], outputs);
      
      // Process results
      return _processDetectionResults(
        outputLocations,
        outputClasses,
        outputScores,
        numDetections[0].toInt(),
      );
    } catch (e) {
      _logger.severe('Error processing frame: $e');
      return [];
    }
  }

  img.Image _convertYUV420ToRGB(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final rgbImage = img.Image(width: width, height: height);

    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
        final int index = y * width + x;

        final yValue = yPlane[index];
        final uValue = uPlane[uvIndex];
        final vValue = vPlane[uvIndex];

        // Convert YUV to RGB
        int r = (yValue + 1.13983 * (vValue - 128)).round();
        int g = (yValue - 0.39465 * (uValue - 128) - 0.58060 * (vValue - 128)).round();
        int b = (yValue + 2.03211 * (uValue - 128)).round();

        // Clamp RGB values
        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        rgbImage.setPixelRgb(x, y, r, g, b);
      }
    }

    return rgbImage;
  }

  Float32List _imageToByteListFloat32(img.Image image) {
    var convertedBytes = Float32List(1 * 112 * 112 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < 112; i++) {
      for (var j = 0; j < 112; j++) {
        int pixel = image.getPixel(j, i) as int;
        // Extract RGBA components from pixel value
        int r = (pixel >> 24) & 0xFF;
        int g = (pixel >> 16) & 0xFF;
        int b = (pixel >> 8) & 0xFF;

        // Normalize and store pixel values
        buffer[pixelIndex++] = (r - 128) / 128.0;
        buffer[pixelIndex++] = (g - 128) / 128.0;
        buffer[pixelIndex++] = (b - 128) / 128.0;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  }

  List<Detection> _processDetectionResults(
    List<List<double>> locations,
    List<double> classes,
    List<double> scores,
    int numDetections,
  ) {
    final List<Detection> detections = [];
    
    for (var i = 0; i < min(numDetections, _numResults); i++) {
      if (scores[i] >= _threshold) {
        final detection = Detection(
          boundingBox: Rect.fromLTRB(
            locations[i][1] * _inputSize,
            locations[i][0] * _inputSize,
            locations[i][3] * _inputSize,
            locations[i][2] * _inputSize,
          ),
          label: _labels?[classes[i].toInt()] ?? 'unknown',
          confidence: scores[i],
        );
        detections.add(detection);
      }
    }
    
    return detections;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

class Detection {
  final Rect boundingBox;
  final String label;
  final double confidence;

  Detection({
    required this.boundingBox,
    required this.label,
    required this.confidence,
  });
}
