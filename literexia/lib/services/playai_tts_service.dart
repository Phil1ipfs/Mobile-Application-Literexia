// lib/services/playai_tts_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class PlayAITTSService {
  static const String _apiKey = 'hJRYkqzoZyW3BS8pQnNEK9OhIXv2';
  static const String _baseUrl = 'https://api.play.ai/api/v1/tts';
  static const String _voiceId = 'jaro-conversational-tagalog'; // Jaro Conversational (Tagalog)
  
  static PlayAITTSService? _instance;
  static PlayAITTSService get instance => _instance ??= PlayAITTSService._();
  
  PlayAITTSService._();
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  
  // Cache to store generated audio files
  final Map<String, String> _audioCache = {};
  
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  
  /// Generate speech from text using PlayAI API
  Future<Uint8List?> _generateSpeech(String text) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'X-USER-ID': 'literexia-app', // Optional user ID for tracking
        },
        body: jsonEncode({
          'text': text,
          'voice': _voiceId,
          'output_format': 'mp3',
          'speed': 1.0,
          'sample_rate': 24000,
        }),
      );
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('PlayAI TTS Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('PlayAI TTS Exception: $e');
      return null;
    }
  }
  
  /// Cache audio file locally
  Future<String?> _cacheAudioFile(String text, Uint8List audioData) async {
    try {
      final directory = await getTemporaryDirectory();
      final hash = text.hashCode.toString();
      final filePath = '${directory.path}/tts_$hash.mp3';
      
      final file = File(filePath);
      await file.writeAsBytes(audioData);
      
      _audioCache[text] = filePath;
      return filePath;
    } catch (e) {
      print('Error caching audio file: $e');
      return null;
    }
  }
  
  /// Speak the given text
  Future<bool> speak(String text, {
    bool cache = true,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    if (text.trim().isEmpty) return false;
    
    try {
      _isLoading = true;
      onStart?.call();
      
      String? audioFilePath;
      
      // Check cache first
      if (cache && _audioCache.containsKey(text)) {
        audioFilePath = _audioCache[text];
        print('Using cached audio for: ${text.substring(0, text.length.clamp(0, 50))}...');
      } else {
        // Generate new audio
        print('Generating new audio for: ${text.substring(0, text.length.clamp(0, 50))}...');
        final audioData = await _generateSpeech(text);
        
        if (audioData != null) {
          if (cache) {
            audioFilePath = await _cacheAudioFile(text, audioData);
          } else {
            // Create temporary file without caching
            final directory = await getTemporaryDirectory();
            final tempPath = '${directory.path}/temp_tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
            final tempFile = File(tempPath);
            await tempFile.writeAsBytes(audioData);
            audioFilePath = tempPath;
          }
        }
      }
      
      _isLoading = false;
      
      if (audioFilePath != null && File(audioFilePath).existsSync()) {
        // Play the audio file
        await _audioPlayer.setFilePath(audioFilePath);
        
        _isPlaying = true;
        await _audioPlayer.play();
        
        // Wait for completion
        await _audioPlayer.playerStateStream
            .where((state) => state.processingState == ProcessingState.completed)
            .first;
        
        _isPlaying = false;
        onComplete?.call();
        
        // Clean up temporary files (non-cached)
        if (!cache) {
          try {
            await File(audioFilePath).delete();
          } catch (e) {
            print('Error deleting temp file: $e');
          }
        }
        
        return true;
      } else {
        _isPlaying = false;
        onError?.call();
        return false;
      }
    } catch (e) {
      print('Error in speak method: $e');
      _isLoading = false;
      _isPlaying = false;
      onError?.call();
      return false;
    }
  }
  
  /// Stop current speech
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }
  
  /// Pause current speech
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }
  
  /// Resume paused speech
  Future<void> resume() async {
    try {
      await _audioPlayer.play();
    } catch (e) {
      print('Error resuming audio: $e');
    }
  }
  
  /// Clear the audio cache
  Future<void> clearCache() async {
    try {
      for (final filePath in _audioCache.values) {
        final file = File(filePath);
        if (file.existsSync()) {
          await file.delete();
        }
      }
      _audioCache.clear();
      print('TTS cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
  
  /// Check if TTS is available (API is accessible)
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.play.ai/api/v1/voices'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('TTS availability check failed: $e');
      return false;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
    clearCache();
  }
}