import 'dart:typed_data';
import 'package:fftea/fftea.dart' as fftea;
import 'dart:math';
import 'package:logging/logging.dart';

final _logger = Logger('AudioProcessor');

class AudioProcessor {
  bool _isProcessing = false;
  final int _sampleRate = 16000;
  final int _fftSize = 512;
  
  // FFT processor for spectrogram generation
  late final fftea.FFT _fft;
  
  // Audio detection parameters
  static const double _voiceFreqLow = 85.0;   // Hz
  static const double _voiceFreqHigh = 255.0; // Hz
  static const double _dogBarkFreqLow = 250.0;  // Hz
  static const double _dogBarkFreqHigh = 1500.0; // Hz
  static const double _sirenFreqLow = 600.0;   // Hz
  static const double _sirenFreqHigh = 1000.0; // Hz
  static const double _energyThreshold = -50.0; // dB
  static const double _voiceThreshold = -40.0;  // dB
  
  Future<void> initialize() async {
    try {
      // Initialize FFT processor
      _fft = fftea.FFT(_fftSize);
    } catch (e) {
      _logger.severe('Error initializing audio processor: $e');
      rethrow;
    }
  }

  Future<AudioAnalysisResult> processAudioBuffer(Float64List buffer) async {
    if (_isProcessing) return AudioAnalysisResult.empty();
    _isProcessing = true;

    try {
      // Generate spectrogram
      final spectrogram = _generateSpectrogram(buffer);
      
      // Analyze audio features
      final features = _analyzeAudioFeatures(spectrogram);
      
      // Detect sounds based on features
      final detectedSounds = _detectSounds(features);
      
      return AudioAnalysisResult(
        hasVoice: detectedSounds.contains(SoundType.voice),
        environmentalSound: detectedSounds.isNotEmpty ? 
          SoundClassification(
            label: detectedSounds.first.toString(),
            confidence: features.confidence,
          ) : null,
        confidence: features.confidence,
      );
    } catch (e) {
      _logger.severe('Error processing audio buffer: $e');
      return AudioAnalysisResult.empty();
    } finally {
      _isProcessing = false;
    }
  }

  List<List<double>> _generateSpectrogram(Float64List buffer) {
    final spectrogramFrames = <List<double>>[];
    final frameSize = _fftSize;
    final hopSize = frameSize ~/ 2;

    // Create window function
    final window = List<double>.generate(frameSize, 
      (i) => 0.5 * (1 - cos(2 * pi * i / (frameSize - 1)))
    );

    for (var i = 0; i < buffer.length - frameSize; i += hopSize) {
      // Extract frame
      final frame = buffer.sublist(i, i + frameSize);
      
      // Apply window
      final windowedFrame = List<double>.generate(frameSize,
        (j) => frame[j] * window[j]
      );
      
      // Compute FFT
      final spectrum = _fft.realFft(windowedFrame);
      
      // Convert to magnitude spectrum (only first half due to symmetry)
      final magnitudes = List<double>.filled(frameSize ~/ 2, 0);
      for (var j = 0; j < frameSize ~/ 2; j++) {
        final complex = spectrum[j];
        final real = complex.x;
        final imag = complex.y;
        magnitudes[j] = pow(real * real + imag * imag, 0.5).toDouble();
      }
      
      // Convert to dB scale
      for (var j = 0; j < magnitudes.length; j++) {
        if (magnitudes[j] > 0) {
          magnitudes[j] = 20 * log(magnitudes[j]) / ln10;
        } else {
          magnitudes[j] = -100; // -100 dB floor
        }
      }
      
      spectrogramFrames.add(magnitudes);
    }
    
    return spectrogramFrames;
  }

  AudioFeatures _analyzeAudioFeatures(List<List<double>> spectrogram) {
    // Calculate frequency resolution
    final freqResolution = _sampleRate / (2.0 * spectrogram[0].length);
    
    // Initialize feature accumulators
    var totalEnergy = 0.0;
    var voiceBandEnergy = 0.0;
    var dogBarkEnergy = 0.0;
    var sirenEnergy = 0.0;
    var peakFrequency = 0.0;
    var maxEnergy = -double.infinity;
    
    // Analyze each frame
    for (final frame in spectrogram) {
      for (var i = 0; i < frame.length; i++) {
        final freq = i * freqResolution;
        final energy = frame[i];
        
        // Update total energy
        totalEnergy += energy;
        
        // Track peak frequency
        if (energy > maxEnergy) {
          maxEnergy = energy;
          peakFrequency = freq;
        }
        
        // Accumulate band energies
        if (freq >= _voiceFreqLow && freq <= _voiceFreqHigh) {
          voiceBandEnergy += energy;
        }
        if (freq >= _dogBarkFreqLow && freq <= _dogBarkFreqHigh) {
          dogBarkEnergy += energy;
        }
        if (freq >= _sirenFreqLow && freq <= _sirenFreqHigh) {
          sirenEnergy += energy;
        }
      }
    }
    
    // Normalize energies by number of frames
    final numFrames = spectrogram.length.toDouble();
    totalEnergy /= numFrames;
    voiceBandEnergy /= numFrames;
    dogBarkEnergy /= numFrames;
    sirenEnergy /= numFrames;
    
    return AudioFeatures(
      totalEnergy: totalEnergy,
      voiceBandEnergy: voiceBandEnergy,
      dogBarkEnergy: dogBarkEnergy,
      sirenEnergy: sirenEnergy,
      peakFrequency: peakFrequency,
      confidence: (maxEnergy + 100) / 100, // Normalize to 0-1 range
    );
  }

  Set<SoundType> _detectSounds(AudioFeatures features) {
    final detectedSounds = <SoundType>{};
    
    // Check if total energy is above threshold
    if (features.totalEnergy > _energyThreshold) {
      // Check for voice
      if (features.voiceBandEnergy > _voiceThreshold &&
          features.peakFrequency >= _voiceFreqLow &&
          features.peakFrequency <= _voiceFreqHigh) {
        detectedSounds.add(SoundType.voice);
      }
      
      // Check for dog bark
      if (features.dogBarkEnergy > _energyThreshold &&
          features.peakFrequency >= _dogBarkFreqLow &&
          features.peakFrequency <= _dogBarkFreqHigh) {
        detectedSounds.add(SoundType.dogBark);
      }
      
      // Check for siren
      if (features.sirenEnergy > _energyThreshold &&
          features.peakFrequency >= _sirenFreqLow &&
          features.peakFrequency <= _sirenFreqHigh) {
        detectedSounds.add(SoundType.siren);
      }
    }
    
    return detectedSounds;
  }

  void dispose() {
    // No resources to dispose
  }
}

class AudioFeatures {
  final double totalEnergy;
  final double voiceBandEnergy;
  final double dogBarkEnergy;
  final double sirenEnergy;
  final double peakFrequency;
  final double confidence;

  AudioFeatures({
    required this.totalEnergy,
    required this.voiceBandEnergy,
    required this.dogBarkEnergy,
    required this.sirenEnergy,
    required this.peakFrequency,
    required this.confidence,
  });
}

enum SoundType {
  voice,
  dogBark,
  siren,
}

class AudioAnalysisResult {
  final bool hasVoice;
  final SoundClassification? environmentalSound;
  final double confidence;

  AudioAnalysisResult({
    required this.hasVoice,
    this.environmentalSound,
    required this.confidence,
  });

  factory AudioAnalysisResult.empty() {
    return AudioAnalysisResult(
      hasVoice: false,
      environmentalSound: null,
      confidence: 0.0,
    );
  }
}

class SoundClassification {
  final String label;
  final double confidence;

  SoundClassification({
    required this.label,
    required this.confidence,
  });
}
