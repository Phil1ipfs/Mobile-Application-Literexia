// lib/features/settings/provider/tts_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Text-to-Speech Provider using Flutter TTS
///
/// This provider manages text-to-speech functionality using the system's built-in TTS engine.
class TTSProvider extends ChangeNotifier {
  // TTS state
  bool _isEnabled = true;
  bool _isAvailable = false;
  bool _isPlaying = false;
  String _connectionStatus = 'Not initialized';
  String _lastError = '';
  double _currentSpeed = 0.4; // Default to 0.4 (60% slower than normal)

  // Voice settings
  String? _currentVoice;
  List<Map<String, String>> _availableVoices = [];

  // Flutter TTS instance
  final FlutterTts _tts = FlutterTts();

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isAvailable => _isAvailable;
  bool get isPlaying => _isPlaying;
  String get connectionStatus => _connectionStatus;
  String get lastError => _lastError;
  double get currentSpeed => _currentSpeed;
  String? get currentVoice => _currentVoice;
  List<Map<String, String>> get availableVoices => _availableVoices;

  // Constructor
  TTSProvider() {
    _tts.setCompletionHandler(() {
      _isPlaying = false;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      _isPlaying = false;
      _lastError = msg;
      notifyListeners();
    });
  }

  // Initialize TTS
  Future<void> initialize() async {
    try {
      _connectionStatus = 'Initializing TTS...';
      notifyListeners();

      // Set up basic TTS engine settings
      await _tts.setLanguage('fil-PH'); // Filipino
      await _tts.setSpeechRate(_currentSpeed);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Get available voices
      await _loadVoices();

      // Try to find and set Jaro Conversational voice if available
      await _trySetJaroVoice();

      // Check if TTS is available
      final available = await _tts.isLanguageAvailable('fil-PH');
      _isAvailable = available ?? false;
      _connectionStatus = _isAvailable
          ? 'TTS initialized successfully${_currentVoice != null ? " with voice: $_currentVoice" : ""}'
          : 'Filipino TTS not available';
    } catch (e) {
      _isAvailable = false;
      _connectionStatus = 'Error: $e';
      _lastError = e.toString();
    }
    notifyListeners();
  }

  // Load available voices
  Future<void> _loadVoices() async {
    try {
      final voices = await _tts.getVoices;
      if (voices != null) {
        _availableVoices = [];

        // Convert to list of maps
        for (var voice in voices) {
          if (voice is Map) {
            final Map<String, String> voiceMap = {};
            voice.forEach((key, value) {
              voiceMap[key.toString()] = value.toString();
            });
            _availableVoices.add(voiceMap);
          }
        }

        // Print available voices for debugging
        print('Available voices: $_availableVoices');
      }
    } catch (e) {
      print('Error loading voices: $e');
    }
  }

  // Try to find and set Jaro Conversational voice
  Future<bool> _trySetJaroVoice() async {
    try {
      // First try exact match for "jaro conversational"
      var jaroVoice = _findVoiceByName('jaro conversational');

      // If not found, try with just "jaro"
      if (jaroVoice == null) {
        jaroVoice = _findVoiceByNameContains('jaro');
      }

      // If still not found, try any Filipino voice
      if (jaroVoice == null) {
        jaroVoice = _findVoiceByLanguage('fil');
      }

      // If we found a suitable voice, set it
      if (jaroVoice != null) {
        final voiceName = jaroVoice['name'] ?? jaroVoice['voiceName'];
        if (voiceName != null) {
          await _tts.setVoice({"name": voiceName});
          _currentVoice = voiceName;
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error setting Jaro voice: $e');
      return false;
    }
  }

  // Find voice by exact name
  Map<String, String>? _findVoiceByName(String name) {
    try {
      return _availableVoices.firstWhere(
        (voice) =>
            (voice['name']?.toLowerCase() == name.toLowerCase()) ||
            (voice['voiceName']?.toLowerCase() == name.toLowerCase()),
      );
    } catch (e) {
      return null;
    }
  }

  // Find voice by partial name match
  Map<String, String>? _findVoiceByNameContains(String nameContains) {
    try {
      return _availableVoices.firstWhere(
        (voice) =>
            (voice['name']
                    ?.toLowerCase()
                    .contains(nameContains.toLowerCase()) ??
                false) ||
            (voice['voiceName']
                    ?.toLowerCase()
                    .contains(nameContains.toLowerCase()) ??
                false),
      );
    } catch (e) {
      return null;
    }
  }

  // Find voice by language code
  Map<String, String>? _findVoiceByLanguage(String langCode) {
    try {
      return _availableVoices.firstWhere(
        (voice) =>
            (voice['locale']?.toLowerCase().contains(langCode.toLowerCase()) ??
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

  // Set voice by name
  Future<bool> setVoice(String voiceName) async {
    try {
      await _tts.setVoice({"name": voiceName});
      _currentVoice = voiceName;
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
      await _tts.setSpeechRate(speed);
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

      // Set voice if specified
      if (voice != null && voice != _currentVoice) {
        try {
          await _tts.setVoice({"name": voice});
          _currentVoice = voice;
        } catch (e) {
          print('Warning: Could not set voice $voice: $e');
        }
      }

      // Set speech rate - use provided speed or default to current speed
      final double useSpeed = speed ?? _currentSpeed;
      await _tts.setSpeechRate(useSpeed);

      // Start speaking
      if (onStart != null) onStart();
      final result = await _tts.speak(text);

      // Check if speak was successful
      if (result == 1) {
        // Success - TTS will call completion handler when done
        return true;
      } else {
        _isPlaying = false;
        _lastError = 'Failed to start TTS';
        notifyListeners();
        if (onError != null) onError();
        return false;
      }
    } catch (e) {
      print('TTS Error: $e');
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
      await _tts.stop();
      _isPlaying = false;
      notifyListeners();
    }
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

  // Get debug info about available voices
  String getVoicesDebugInfo() {
    if (_availableVoices.isEmpty) {
      return 'No voices available';
    }

    return _availableVoices.map((voice) {
      return 'Voice: ${voice['name'] ?? 'Unknown'}\n'
          'Language: ${voice['locale'] ?? voice['language'] ?? 'Unknown'}\n'
          '${voice.entries.where((e) => e.key != 'name' && e.key != 'locale' && e.key != 'language').map((e) => '${e.key}: ${e.value}').join('\n')}';
    }).join('\n\n');
  }

  // Clean up resources
  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
