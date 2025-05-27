// lib/features/settings/provider/tts_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

/// PlayAI Text-to-Speech Provider
/// 
/// This provider manages text-to-speech functionality using the PlayAI API.
class TTSProvider extends ChangeNotifier {
  // PlayAI API credentials
  static const String _userId = '9g1mvXwwvGOD21KZn6ZGa58xhS23';
  static const String _secretKey = 'ak-0f52a8df03154c369821a78e90ecad98';
  static const String _apiUrl = 'https://api.play.ai/v1/tts';

  // TTS state
  bool _isEnabled = true;
  bool _isAvailable = false;
  bool _isPlaying = false;
  String _connectionStatus = 'Not initialized';
  String _lastError = '';
  
  // Audio player for TTS
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Cache for TTS audio to prevent repeated API calls
  final Map<String, String> _audioCache = {};
  
  // Getters
  bool get isEnabled => _isEnabled;
  bool get isAvailable => _isAvailable;
  bool get isPlaying => _isPlaying;
  String get connectionStatus => _connectionStatus;
  String get lastError => _lastError;
  
  // Constructor
  TTSProvider() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        notifyListeners();
      }
    });
  }
  
  // Initialize TTS
  Future<void> initialize() async {
    try {
      _connectionStatus = 'Checking connection...';
      notifyListeners();
      
      // Try to connect to the PlayAI API
      final result = await _checkApiAvailability();
      _isAvailable = result;
      _connectionStatus = result 
          ? 'PlayAI TTS service connected' 
          : 'Connection failed - check internet';
    } catch (e) {
      _isAvailable = false;
      _connectionStatus = 'Error: $e';
      _lastError = e.toString();
    }
    notifyListeners();
  }
  
  // Check if the API is available
  Future<bool> _checkApiAvailability() async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': _userId,          // FIXED: Changed from 'User-ID' to 'X-User-Id'
          'Authorization': 'Bearer $_secretKey',
        },
        body: jsonEncode({
          'text': 'Test connection',
          'voice': 'filipino',
          'speed': 1.0,
        }),
      ).timeout(const Duration(seconds: 10));
      
      print('PlayAI Response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        _lastError = 'API Error: ${response.statusCode} - ${response.body}';
        return false;
      }
    } catch (e) {
      print('PlayAI Connection Error: $e');
      _lastError = 'Connection Error: $e';
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
  
  // Refresh connection to PlayAI
  Future<bool> refreshConnection() async {
    await initialize();
    return _isAvailable;
  }
  
  // Speak text and return success status
  Future<bool> speakText(
    String text, {
    String voice = 'filipino',
    double speed = 1.0,
    bool cache = true,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    if (!_isEnabled || text.isEmpty) {
      if (onError != null) onError();
      return false;
    }
    
    // If the service isn't available, try to initialize it once more
    if (!_isAvailable) {
      await initialize();
      // If still not available after re-init, fail
      if (!_isAvailable) {
        if (onError != null) onError();
        return false;
      }
    }
    
    // Stop any currently playing speech
    await stopSpeaking();
    
    try {
      _isPlaying = true;
      notifyListeners();
      
      String audioUrl;
      
      // Check cache first if caching is enabled
      final cacheKey = '$text-$voice-$speed';
      if (cache && _audioCache.containsKey(cacheKey)) {
        audioUrl = _audioCache[cacheKey]!;
      } else {
        // Call PlayAI API to convert text to speech
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-User-Id': _userId,          // FIXED: Changed from 'User-ID' to 'X-User-Id'
            'Authorization': 'Bearer $_secretKey',
          },
          body: jsonEncode({
            'text': text,
            'voice': voice,
            'speed': speed,
          }),
        );
        
        print('PlayAI TTS Response: ${response.statusCode} - ${response.body}');
        
        if (response.statusCode != 200) {
          _isPlaying = false;
          _lastError = 'API Error: ${response.statusCode} - ${response.body}';
          notifyListeners();
          if (onError != null) onError();
          return false;
        }
        
        final responseData = jsonDecode(response.body);
        audioUrl = responseData['audio_url'];
        
        // Cache the audio URL
        if (cache) {
          _audioCache[cacheKey] = audioUrl;
        }
      }
      
      // Play the audio
      await _audioPlayer.setUrl(audioUrl);
      if (onStart != null) onStart();
      await _audioPlayer.play();
      
      // Setup completion callback
      _audioPlayer.playerStateStream.first.then((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          notifyListeners();
          if (onComplete != null) onComplete();
        }
      });
      
      return true;
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
      await _audioPlayer.stop();
      _isPlaying = false;
      notifyListeners();
    }
  }
  
  // Test TTS with a sample text
  Future<bool> testTTS() async {
    return await speakText(
      'Ito ay isang pagsubok ng text-to-speech sa Filipino. Kung naririnig mo ito, gumagana na ang PlayAI TTS.',
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
  
  // Clear audio cache
  void clearCache() {
    _audioCache.clear();
  }
  
  // Clean up resources
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}