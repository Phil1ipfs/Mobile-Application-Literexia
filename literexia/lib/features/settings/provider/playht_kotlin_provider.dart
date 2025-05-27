// lib/features/settings/provider/playht_kotlin_provider.dart
import 'package:flutter/material.dart';
import 'package:literexia/services/playht_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
// import '../theme_provider.dart';
// TODO: Update the import path below if theme_provider.dart exists elsewhere, for example:

/// PlayHT TTS Provider using Kotlin implementation
/// 
/// This provider integrates with the native Kotlin PlayHTService
/// to provide high-quality TTS using PlayHT voices.
class PlayHTKotlinProvider extends ChangeNotifier {
  // TTS state
  bool _isEnabled = true;
  bool _isAvailable = false;
  bool _isPlaying = false;
  String _connectionStatus = 'Not initialized';
  String _lastError = '';
  double _currentSpeed = 1.0;
  
  // Voice settings
  String? _currentVoice;
  List<Map<String, dynamic>> _availableVoices = [];
  List<Map<String, dynamic>> _filipinoVoices = [];
  
  // PlayHT service
  final PlayHTService _playHTService = PlayHTService();
  
  // Getters
  bool get isEnabled => _isEnabled;
  bool get isAvailable => _isAvailable;
  bool get isPlaying => _isPlaying || _playHTService.isPlaying;
  String get connectionStatus => _connectionStatus;
  String get lastError => _lastError;
  double get currentSpeed => _currentSpeed;
  String? get currentVoice => _currentVoice;
  List<Map<String, dynamic>> get availableVoices => _availableVoices;
  List<Map<String, dynamic>> get filipinoVoices => _filipinoVoices;
  
  // Constructor
  PlayHTKotlinProvider() {
    initialize();
  }
  
  // Initialize the provider
  Future<void> initialize() async {
    try {
      _connectionStatus = 'Initializing PlayHT TTS...';
      notifyListeners();
      
      // Fetch available voices
      await _fetchVoices();
      
      // Set the default voice (Jaro or Filipino)
      await _setDefaultVoice();
      
      _isAvailable = true;
      _connectionStatus = 'PlayHT TTS initialized successfully';
      notifyListeners();
    } catch (e) {
      _isAvailable = false;
      _connectionStatus = 'Error: $e';
      _lastError = e.toString();
      notifyListeners();
    }
  }
  
  // Fetch available voices
  Future<void> _fetchVoices() async {
    try {
      // Get all voices
      final voices = await _playHTService.getVoices();
      _availableVoices = voices;
      
      // Get Filipino voices
      _filipinoVoices = await _playHTService.getFilipinoVoices();
      
      if (_availableVoices.isEmpty) {
        throw Exception('No voices available');
      }
      
      notifyListeners();
    } catch (e) {
      _lastError = 'Error fetching voices: $e';
      throw Exception('Failed to fetch voices: $e');
    }
  }
  
  // Set default voice (Jaro or Filipino)
  Future<void> _setDefaultVoice() async {
    try {
      // First try to find Jaro voice
      final jaroVoice = _availableVoices.firstWhere(
        (voice) => voice['name']?.toString().toLowerCase().contains('jaro') ?? false,
        orElse: () => {},
      );
      
      // If Jaro not found, try to find any Filipino voice
      if (jaroVoice.isNotEmpty) {
        _currentVoice = jaroVoice['id'];
      } else if (_filipinoVoices.isNotEmpty) {
        _currentVoice = _filipinoVoices.first['id'];
      } else {
        // Default to a known voice ID if no Filipino voices found
        _currentVoice = 's3://voice-cloning-zero-shot/67a8d750-e675-4ce8-856c-14a71cf15585/original/manifest.json';
      }
      
      notifyListeners();
    } catch (e) {
      _lastError = 'Error setting default voice: $e';
      print('Error setting default voice: $e');
    }
  }
  
  // Set voice by ID
  Future<bool> setVoice(String voiceId) async {
    try {
      _currentVoice = voiceId;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Failed to set voice: $e';
      return false;
    }
  }
  
  // Enable or disable TTS
  void setEnabled(bool value) {
    if (_isEnabled != value) {
      _isEnabled = value;
      if (!_isEnabled) {
        stopSpeaking();
      }
      notifyListeners();
    }
  }
  
  // Set speech speed
  void setSpeed(double speed) {
    if (_currentSpeed != speed) {
      _currentSpeed = speed;
      notifyListeners();
    }
  }
  
  // Refresh connection
  Future<bool> refreshConnection() async {
    await initialize();
    return _isAvailable;
  }
  
  // Speak text and return success status
  Future<bool> speakText(
    String text, {
    String? voice,
    double? speed,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    if (!_isEnabled || text.isEmpty) {
      if (onError != null) onError();
      return false;
    }
    
    // Stop any currently playing speech
    await stopSpeaking();
    
    try {
      _isPlaying = true;
      notifyListeners();
      
      if (onStart != null) onStart();
      
      // Use provided voice or current voice
      final useVoice = voice ?? _currentVoice;
      
      // Use provided speed or current speed
      final useSpeed = speed ?? _currentSpeed;
      
      // Speak the text
      final success = await _playHTService.speakText(
        text,
        voiceId: useVoice,
        speed: useSpeed,
      );
      
      if (!success) {
        _isPlaying = false;
        _lastError = 'Failed to speak text';
        notifyListeners();
        if (onError != null) onError();
        return false;
      }
      
      // Set up completion handling
      Future.delayed(Duration(milliseconds: 500), () {
        _checkPlaybackStatus(onComplete);
      });
      
      return true;
    } catch (e) {
      _isPlaying = false;
      _lastError = 'Error: $e';
      notifyListeners();
      if (onError != null) onError();
      return false;
    }
  }
  
  // Check playback status periodically to detect completion
  void _checkPlaybackStatus(VoidCallback? onComplete) {
    if (!_playHTService.isPlaying) {
      _isPlaying = false;
      notifyListeners();
      if (onComplete != null) onComplete();
    } else {
      Future.delayed(Duration(milliseconds: 500), () {
        _checkPlaybackStatus(onComplete);
      });
    }
  }
  
  // Stop speaking
  Future<void> stopSpeaking() async {
    await _playHTService.stopAudio();
    _isPlaying = false;
    notifyListeners();
  }
  
  // Test TTS with a sample text
  Future<bool> testTTS() async {
    return await speakText(
      'Ito ay isang pagsubok ng text-to-speech sa Filipino. Kung naririnig mo ito, gumagana na ang TTS.',
      onStart: () {
        _isPlaying = true;
        notifyListeners();
      },
      onComplete: () {
        _isPlaying = false;
        notifyListeners();
      },
      onError: () {
        _isPlaying = false;
        notifyListeners();
      },
    );
  }
  
  // Clean up resources
  @override
  void dispose() {
    stopSpeaking();
    super.dispose();
  }
}
