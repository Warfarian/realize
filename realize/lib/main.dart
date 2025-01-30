import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Get available cameras
  final cameras = await availableCameras();
  
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Realize',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: ServiceDogScreen(cameras: cameras),
    );
  }
}

class ServiceDogScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ServiceDogScreen({super.key, required this.cameras});

  @override
  State<ServiceDogScreen> createState() => _ServiceDogScreenState();
}

class _ServiceDogScreenState extends State<ServiceDogScreen> {
  CameraController? _cameraController;
  final _audioRecorder = AudioRecorder();
  bool _isCameraInitialized = false;
  bool _hasPermissions = false;
  bool _isRecording = false;
  String? _currentRecordingPath;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final camera = await Permission.camera.request();
    final microphone = await Permission.microphone.request();
    
    setState(() {
      _hasPermissions = camera.isGranted && microphone.isGranted;
    });
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;
    
    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController?.initialize();
      if (!mounted) return;
      
      await _cameraController?.startImageStream((image) {
        // TODO: Process camera frames here
      });
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<String> _getRecordingPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/recording_$timestamp.m4a';
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
        _currentRecordingPath = null;
      } else {
        _currentRecordingPath = await _getRecordingPath();
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _currentRecordingPath!,
        );
      }
      setState(() {
        _isRecording = !_isRecording;
      });
    } catch (e) {
      debugPrint('Error toggling recording: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermissions) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Camera and microphone permissions are required'),
              ElevatedButton(
                onPressed: _checkPermissions,
                child: const Text('Grant Permissions'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Realize'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: CameraPreview(_cameraController!),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filled(
                  onPressed: _toggleRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                ),
                IconButton.filled(
                  onPressed: () {
                    // TODO: Toggle camera processing
                  },
                  icon: const Icon(Icons.visibility),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
