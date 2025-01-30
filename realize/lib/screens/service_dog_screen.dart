import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../ml/vision/vision_processor.dart';
import '../ml/vision/detection_overlay.dart';
import '../ml/audio/audio_processor.dart';
import 'package:logging/logging.dart';

final _logger = Logger('ServiceDogScreen');

class ServiceDogScreen extends StatefulWidget {
  const ServiceDogScreen({super.key});

  @override
  State<ServiceDogScreen> createState() => _ServiceDogScreenState();
}

class _ServiceDogScreenState extends State<ServiceDogScreen> {
  CameraController? _controller;
  VisionProcessor? _visionProcessor;
  AudioProcessor? _audioProcessor;
  List<Detection> _currentDetections = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeProcessors();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _logger.severe('No cameras available');
        return;
      }

      final camera = cameras.first;
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _controller!.initialize();
      if (!mounted) return;

      _controller!.startImageStream(_processFrame);
      setState(() {});
    } catch (e) {
      _logger.severe('Error initializing camera: $e');
    }
  }

  Future<void> _initializeProcessors() async {
    try {
      _visionProcessor = VisionProcessor();
      _audioProcessor = AudioProcessor();

      await Future.wait([
        _visionProcessor!.initialize(),
        _audioProcessor!.initialize(),
      ]);
    } catch (e) {
      _logger.severe('Error initializing processors: $e');
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || _visionProcessor == null) return;
    _isProcessing = true;

    try {
      final detections = await _visionProcessor!.processFrame(image);
      if (mounted) {
        setState(() {
          _currentDetections = detections;
        });
      }
    } catch (e) {
      _logger.warning('Error processing frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final screenSize = MediaQuery.of(context).size;
    final scale = screenSize.aspectRatio * _controller!.value.aspectRatio;
    final previewSize = Size(
      _controller!.value.previewSize!.height,
      _controller!.value.previewSize!.width,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Service Dog')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(_controller!),
            ),
          ),
          DetectionOverlay(
            detections: _currentDetections,
            previewSize: previewSize,
            screenSize: screenSize,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _visionProcessor?.dispose();
    _audioProcessor?.dispose();
    super.dispose();
  }
}
