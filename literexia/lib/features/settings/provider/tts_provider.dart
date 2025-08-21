// lib/features/settings/provider/tts_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/playht_service.dart';

/// Text-to-Speech Provider using PlayAI TTS
///
/// This provider manages text-to-speech functionality using PlayAI TTS service.
class TTSProvider extends ChangeNotifier {
  // TTS state
  bool _isEnabled = true;
  bool _isAvailable = false;
  bool _isPlaying = false;
  String _connectionStatus = 'Not initialized';
  String _lastError = '';
  double _currentSpeed = 1.0; // Default speed for PlayAI

  // Voice settings
  String? _currentVoice;
  List<Map<String, dynamic>> _availableVoices = [];

  // PlayAI TTS instance
  final PlayHTService _playaiTTS = PlayHTService();

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
    // Set default voice to Jaro voice
    _currentVoice =
        's3://voice-cloning-zero-shot/67a8d750-e675-4ce8-856c-14a71cf15585/original/manifest.json';
  }

  // Initialize TTS
  Future<void> initialize() async {
    try {
      _connectionStatus = 'Initializing PlayAI TTS...';
      notifyListeners();

      // Get available voices from PlayAI
      await _loadVoices();

      // Set the default Jaro voice
      _currentVoice =
          's3://voice-cloning-zero-shot/67a8d750-e675-4ce8-856c-14a71cf15585/original/manifest.json';

      // Check if PlayAI TTS is available
      _isAvailable = true; // PlayAI TTS is always available if configured properly
      _connectionStatus = 'Play.ai TTS initialized successfully with Jaro Filipino voice';
    } catch (e) {
      _isAvailable = false;
      _connectionStatus = 'Error initializing PlayAI TTS: $e';
      _lastError = e.toString();
    }
    notifyListeners();
  }

  // Load available voices
  Future<void> _loadVoices() async {
    try {
      final voices = await _playaiTTS.getVoices();
      _availableVoices = voices;

      // Add the default Jaro voice if not already in the list
      final jaroVoiceId =
          's3://voice-cloning-zero-shot/67a8d750-e675-4ce8-856c-14a71cf15585/original/manifest.json';
      bool hasJaroVoice = voices.any((voice) => voice['id'] == jaroVoiceId);

      if (!hasJaroVoice) {
        _availableVoices.add({
          'id': jaroVoiceId,
          'name': 'Jaro - Filipino Voice',
          'language': 'Filipino',
          'language_code': 'fil-PH',
          'description': 'Clear Filipino conversational voice'
        });
      }

      print('Available PlayAI voices: $_availableVoices');
    } catch (e) {
      print('Error loading PlayAI voices: $e');
      // Add default Jaro voice even if API call fails
      _availableVoices = [
        {
          'id':
              's3://voice-cloning-zero-shot/67a8d750-e675-4ce8-856c-14a71cf15585/original/manifest.json',
          'name': 'Jaro Conversational',
          'language': 'Filipino',
          'language_code': 'fil-PH'
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
    if (!_isEnabled || text.isEmpty) {
      if (onError != null) onError();
      return false;
    }

    // Stop any currently playing speech
    await stopSpeaking();

    try {
      _isPlaying = true;
      notifyListeners();

      // Set voice if specified, otherwise use current voice
      final String useVoice = voice ??
          _currentVoice ??
          's3://voice-cloning-zero-shot/67a8d750-e675-4ce8-856c-14a71cf15585/original/manifest.json';
      final double useSpeed = speed ?? _currentSpeed;

      // Start speaking callback
      if (onStart != null) onStart();

      // Use PlayAI TTS to speak
      final success = await _playaiTTS.speakText(
        text,
        voiceId: useVoice,
        speed: useSpeed,
      );

      if (success) {
        // Speaking completed successfully
        _isPlaying = false;
        notifyListeners();
        if (onComplete != null) onComplete();
        return true;
      } else {
        _isPlaying = false;
        _lastError = 'Failed to speak with PlayAI TTS';
        notifyListeners();
        if (onError != null) onError();
        return false;
      }
    } catch (e) {
      print('PlayAI TTS Error: $e');
      _lastError = 'Error: $e';
      _isPlaying = false;
      notifyListeners();
      if (onError != null) onError();
      return false;
    }
  }

  // Stop speaking
  Future<void> stopSpeaking() async {
    if (_isPlaying) {
      await _playaiTTS.stopAudio();
      _isPlaying = false;
      notifyListeners();
    }
  }

  // Test TTS with a sample text
  Future<bool> testTTS() async {
    return await speakText(
      'Kumusta! Ito ay pagsubok ng Play.ai text-to-speech gamit ang Jaro voice. Kung naririnig ninyo ito, gumagana na ang TTS.',
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

  // Get debug info about available voices
  String getVoicesDebugInfo() {
    if (_availableVoices.isEmpty) {
      return 'No PlayAI voices available';
    }

    return _availableVoices.map((voice) {
      return 'Voice: ${voice['name'] ?? 'Unknown'}\n'
          'Language: ${voice['language'] ?? voice['language_code'] ?? 'Unknown'}\n'
          'ID: ${voice['id'] ?? 'Unknown'}\n'
          '${voice.entries.where((e) => e.key != 'name' && e.key != 'language' && e.key != 'language_code' && e.key != 'id').map((e) => '${e.key}: ${e.value}').join('\n')}';
    }).join('\n\n');
  }

  // Clean up resources
  @override
  void dispose() {
    _playaiTTS.stopAudio();
    super.dispose();
  }
}
