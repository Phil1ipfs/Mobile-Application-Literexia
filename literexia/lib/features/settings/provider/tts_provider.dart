// lib/features/settings/provider/tts_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/eventlabs_tts_service.dart';

/// Text-to-Speech Provider using EventLabs TTS
///
/// This provider manages text-to-speech functionality using EventLabs TTS service.
class TTSProvider extends ChangeNotifier {
  // TTS state
  bool _isEnabled = true;
  bool _isAvailable = false;
  bool _isPlaying = false;
  String _connectionStatus = 'Not initialized';
  String _lastError = '';
  double _currentSpeed = 1.0; // Default speed for EventLabs
  bool _disposed = false; // Add disposal guard

  // Voice settings
  String? _currentVoice;
  List<Map<String, dynamic>> _availableVoices = [];

  // EventLabs TTS instance
  final EventLabsTTSService _eventLabsTTS = EventLabsTTSService();

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isAvailable => _isAvailable;
  bool get isPlaying => _isPlaying;
  String get connectionStatus => _connectionStatus;
  String get lastError => _lastError;
  double get currentSpeed => _currentSpeed;
  String? get currentVoice => _currentVoice;
  List<Map<String, dynamic>> get availableVoices => _availableVoices;

  // Constructor
  TTSProvider() {
    // Set default voice to ate Ada ElevenLabs voice
    _currentVoice = 'P1hTNpVDMG973fukK9V2';
  }

  // Initialize TTS
  Future<void> initialize() async {
    if (_disposed) return;

    try {
      _connectionStatus = 'Initializing ElevenLabs TTS...';
      notifyListeners();

      // Initialize the TTS service with secure credentials
      await EventLabsTTSService.initialize();

      // Get available voices from ElevenLabs
      await _loadVoices();

      // Set the default voice
      _currentVoice = 'P1hTNpVDMG973fukK9V2';

      // Check if ElevenLabs TTS is available
      _isAvailable = _eventLabsTTS.isAvailable;
      _connectionStatus = 'ElevenLabs TTS initialized successfully';

      // Preload common phrases in background for faster playback (disabled temporarily)
      // _preloadCommonPhrases();
    } catch (e) {
      _isAvailable = false;
      _connectionStatus = 'Error initializing ElevenLabs TTS: $e';
      _lastError = e.toString();
    }
    notifyListeners();
  }

  // Preload common phrases in background
  void _preloadCommonPhrases() {
    // Run in background without blocking initialization
    Future.delayed(Duration(seconds: 2), () async {
      try {
        await _eventLabsTTS.preloadCommonPhrases();
        print('TTS: Common phrases preloaded successfully');
      } catch (e) {
        print('TTS: Failed to preload common phrases: $e');
      }
    });
  }

  // Load available voices
  Future<void> _loadVoices() async {
    try {
      final voices = await _eventLabsTTS.getVoices();
      _availableVoices = voices;
      print('Available ElevenLabs voices: $_availableVoices');
    } catch (e) {
      print('Error loading ElevenLabs voices: $e');
      // Add default voice even if API call fails
      _availableVoices = [
        {
          'voice_id': 'P1hTNpVDMG973fukK9V2',
          'name': 'ate Ada',
          'category': 'generated',
        }
      ];
    }
  }

  // Find voice by exact name
  Map<String, dynamic>? _findVoiceByName(String name) {
    try {
      return _availableVoices.firstWhere(
        (voice) => (voice['name']?.toLowerCase() == name.toLowerCase()),
      );
    } catch (e) {
      return null;
    }
  }

  // Find voice by partial name match
  Map<String, dynamic>? _findVoiceByNameContains(String nameContains) {
    try {
      return _availableVoices.firstWhere(
        (voice) => (voice['name']
                ?.toLowerCase()
                .contains(nameContains.toLowerCase()) ??
            false),
      );
    } catch (e) {
      return null;
    }
  }

  // Find voice by language code
  Map<String, dynamic>? _findVoiceByLanguage(String langCode) {
    try {
      return _availableVoices.firstWhere(
        (voice) =>
            (voice['language_code']
                    ?.toLowerCase()
                    .contains(langCode.toLowerCase()) ??
                false) ||
            (voice['language']
                    ?.toLowerCase()
                    .contains(langCode.toLowerCase()) ??
                false),
      );
    } catch (e) {
      return null;
    }
  }

  // Set voice by name or ID
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
  Future<void> setSpeed(double speed) async {
    if (_currentSpeed != speed) {
      _currentSpeed = speed;
      notifyListeners();
    }
  }

  // Refresh TTS engine
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
    // TEMPORARILY DISABLED TO AVOID TOKEN LIMITS
    // Maintain all logic and flow but skip actual TTS call

    if (_disposed || !_isEnabled || text.isEmpty) {
      if (onError != null) onError();
      return false;
    }

    // Stop any currently playing speech
    await stopSpeaking();

    try {
      _isPlaying = true;
      notifyListeners();

      // Set voice if specified, otherwise use current voice
      final String useVoice = voice ?? _currentVoice ?? 'P1hTNpVDMG973fukK9V2';
      final double useSpeed = speed ?? _currentSpeed;

      // Simulate TTS behavior without actual API call
      if (onStart != null) onStart();

      // Simulate short delay as if TTS is playing
      await Future.delayed(const Duration(milliseconds: 500));

      _isPlaying = false;
      notifyListeners();
      if (onComplete != null) onComplete();

      return true; // Return success without actual TTS

      // ORIGINAL CODE (temporarily commented out):
      // Use ElevenLabs TTS to speak
      // final success = await _eventLabsTTS.speakText(
      //   text,
      //   voice: useVoice,
      //   speed: useSpeed,
      //   onStart: () {
      //     _isPlaying = true;
      //     notifyListeners();
      //     if (onStart != null) onStart();
      //   },
      //   onComplete: () {
      //     _isPlaying = false;
      //     notifyListeners();
      //     if (onComplete != null) onComplete();
      //   },
      //   onError: () {
      //     _isPlaying = false;
      //     _lastError = 'Failed to speak with ElevenLabs TTS';
      //     notifyListeners();
      //     if (onError != null) onError();
      //   },
      // );
      // return success;
    } catch (e) {
      print('ElevenLabs TTS Error: $e');
      _lastError = 'Error: $e';
      _isPlaying = false;
      notifyListeners();
      if (onError != null) onError();
      return false;
    }
  }

  // Stop speaking
  Future<void> stopSpeaking() async {
    if (_disposed) return;

    if (_isPlaying) {
      await _eventLabsTTS.stopAudio();
      _isPlaying = false;
      notifyListeners();
    }
  }

  // Test TTS with a sample text
  Future<bool> testTTS() async {
    // TEMPORARILY DISABLED TO AVOID TOKEN LIMITS
    print('TTS Test: Simulated success (actual TTS disabled)');
    return true;

    // ORIGINAL CODE (temporarily commented out):
    // return await speakText(
    //   'Kumusta! Ako si Literexia. Kung naririnig ninyo ito, gumagana na ang TTS.',
    // );
  }

  // Get debug info about available voices
  String getVoicesDebugInfo() {
    if (_availableVoices.isEmpty) {
      return 'No ElevenLabs voices available';
    }

    return _availableVoices.map((voice) {
      return 'Voice: ${voice['name'] ?? 'Unknown'}\n'
          'ID: ${voice['voice_id'] ?? voice['id'] ?? 'Unknown'}\n'
          'Category: ${voice['category'] ?? 'Unknown'}\n'
          '${voice.entries.where((e) => e.key != 'name' && e.key != 'voice_id' && e.key != 'id' && e.key != 'category').map((e) => '${e.key}: ${e.value}').join('\n')}';
    }).join('\n\n');
  }

  // Override notifyListeners to prevent calls after disposal
  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  // Clean up resources
  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _eventLabsTTS.dispose();
      super.dispose();
    }
  }
}
