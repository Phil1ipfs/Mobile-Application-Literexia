// lib/services/playht_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PlayHTService {
  static const MethodChannel _channel =
      MethodChannel('com.example.literexia/playht');

  // Get API credentials from .env file
  String get _apiKey => dotenv.env['PLAYHT_API_KEY'] ?? '';
  String get _userId => dotenv.env['PLAYHT_USER_ID'] ?? '';

  // Flag to track playback state
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  // Fetch available voices from PlayHT
  Future<List<Map<String, dynamic>>> getVoices() async {
    try {
      // Verify credentials are available
      if (_apiKey.isEmpty || _userId.isEmpty) {
        throw Exception('PlayHT credentials not found in .env file');
      }

      final String result = await _channel.invokeMethod('listVoices', {
        'apiKey': _apiKey,
        'userId': _userId,
      });

      // Parse JSON result
      final List<dynamic> voicesList = jsonDecode(result);
      return voicesList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching voices: $e');
      return [];
    }
  }

  // Find Filipino voices in the list
  Future<List<Map<String, dynamic>>> getFilipinoVoices() async {
    final voices = await getVoices();

    // Filter for any voices that might be Filipino
    // (Look for "Filipino", "Tagalog", "Jaro", etc. in name, language, or other fields)
    return voices.where((voice) {
      final name = voice['name']?.toString().toLowerCase() ?? '';
      final language = voice['language']?.toString().toLowerCase() ?? '';
      final languageCode =
          voice['language_code']?.toString().toLowerCase() ?? '';

      return name.contains('filipino') ||
          name.contains('tagalog') ||
          name.contains('jaro') ||
          language.contains('filipino') ||
          language.contains('tagalog') ||
          languageCode.contains('fil') ||
          languageCode.contains('tl');
    }).toList();
  }

  // Generate speech and get audio URL
  Future<String?> generateSpeech(
    String text, {
    String? voiceId,
    double speed = 1.0,
  }) async {
    try {
      // Verify credentials are available
      if (_apiKey.isEmpty || _userId.isEmpty) {
        throw Exception('PlayHT credentials not found in .env file');
      }

      // Default voice ID if none provided (Jaro voice)
      final String useVoiceId = voiceId ??
          's3://voice-cloning-zero-shot/67a8d750-e675-4ce8-856c-14a71cf15585/original/manifest.json';

      // Call the native method to generate speech
      return await _channel.invokeMethod('generateSpeech', {
        'text': text,
        'voiceId': useVoiceId,
        'speed': speed,
        'apiKey': _apiKey,
        'userId': _userId,
      });
    } catch (e) {
      print('Error generating speech: $e');
      return null;
    }
  }

  // Play audio from URL
  Future<bool> playAudio(String url) async {
    try {
      final result = await _channel.invokeMethod('playAudio', {
        'url': url,
      });

      _isPlaying = result == true;
      return _isPlaying;
    } catch (e) {
      print('Error playing audio: $e');
      _isPlaying = false;
      return false;
    }
  }

  // Stop audio playback
  Future<void> stopAudio() async {
    try {
      await _channel.invokeMethod('stopAudio');
      _isPlaying = false;
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  // Generate and play speech in one call
  Future<bool> speakText(
    String text, {
    String? voiceId,
    double speed = 1.0,
  }) async {
    try {
      // Stop any currently playing audio
      await stopAudio();

      // Generate speech and get URL
      final audioUrl = await generateSpeech(
        text,
        voiceId: voiceId,
        speed: speed,
      );

      if (audioUrl == null || audioUrl.isEmpty) {
        return false;
      }

      // Play the generated audio
      return await playAudio(audioUrl);
    } catch (e) {
      print('Error speaking text: $e');
      return false;
    }
  }

  // Get a specific voice by name
  Future<Map<String, dynamic>?> getVoiceByName(String name) async {
    final voices = await getVoices();

    try {
      return voices.firstWhere((voice) =>
          voice['name']?.toString().toLowerCase() == name.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  // Find voices by language
  Future<List<Map<String, dynamic>>> getVoicesByLanguage(
      String languageCode) async {
    final voices = await getVoices();

    return voices.where((voice) {
      final code = voice['language_code']?.toString().toLowerCase() ?? '';
      return code.startsWith(languageCode.toLowerCase());
    }).toList();
  }
}
