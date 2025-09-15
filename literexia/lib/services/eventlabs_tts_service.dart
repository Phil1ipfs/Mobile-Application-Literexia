// lib/services/eventlabs_tts_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// ElevenLabs Text-to-Speech Service
///
/// This service handles text-to-speech functionality using ElevenLabs API
class EventLabsTTSService {
  static const String _apiKey =
      'sk_14389b784fbda91eb32d0b0600475157f48d5100e01566fc';
  static const String _baseUrl = 'https://api.elevenlabs.io/v1';
  static const String _defaultVoiceId = 'P1hTNpVDMG973fukK9V2'; // ate Ada voice

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  // Getters
  bool get isPlaying => _isPlaying;
  bool get isAvailable =>
      true; // EventLabs API is always available if properly configured

  /// Generate speech from text using ElevenLabs API
  Future<bool> speakText(
    String text, {
    String? voice, // Voice ID
    double speed = 1.0,
    Function? onStart,
    Function? onComplete,
    Function? onError,
  }) async {
    if (text.isEmpty) {
      if (onError != null) onError();
      return false;
    }

    try {
      // Stop any currently playing audio
      await stopAudio();

      _isPlaying = true;
      if (onStart != null) onStart();

      // Use provided voice or default voice
      final voiceId = voice ?? _defaultVoiceId;

      // Make API request to ElevenLabs
      final response = await http.post(
        Uri.parse('$_baseUrl/text-to-speech/$voiceId'),
        headers: {
          'xi-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.75,
            'style': 0.0,
            'use_speaker_boost': true
          }
        }),
      );

      if (response.statusCode == 200) {
        // Save audio data to temporary file
        final audioData = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final audioFile = File(
            '${tempDir.path}/elevenlabs_tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await audioFile.writeAsBytes(audioData);

        // Play the audio file
        await _audioPlayer.setFilePath(audioFile.path);
        await _audioPlayer.play();

        // Wait for playback to complete
        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            if (onComplete != null) onComplete();
            // Clean up temporary file
            audioFile.delete().catchError((e) {
              print('Failed to delete temp file: $e');
              return null;
            });
          }
        });

        return true;
      } else {
        print(
            'ElevenLabs TTS API error: ${response.statusCode} - ${response.body}');
        _isPlaying = false;
        if (onError != null) onError();
        return false;
      }
    } catch (e) {
      print('ElevenLabs TTS error: $e');
      _isPlaying = false;
      if (onError != null) onError();
      return false;
    }
  }

  /// Stop any currently playing audio
  Future<void> stopAudio() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      _isPlaying = false;
    }
  }

  /// Get available voices (ElevenLabs specific voices)
  Future<List<Map<String, dynamic>>> getVoices() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/voices'),
        headers: {
          'xi-api-key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['voices'] ?? []);
      } else {
        print('Failed to fetch voices: ${response.statusCode}');
        return _getDefaultVoices();
      }
    } catch (e) {
      print('Error fetching voices: $e');
      return _getDefaultVoices();
    }
  }

  /// Get default voices as fallback
  List<Map<String, dynamic>> _getDefaultVoices() {
    return [
      {
        'voice_id': _defaultVoiceId,
        'name': 'Default Voice',
        'category': 'generated',
        'preview_url':
            'https://elevenlabs.io/app/voice-library?voiceId=$_defaultVoiceId',
      },
    ];
  }

  /// Test the TTS service with a sample text
  Future<bool> testTTS() async {
    return await speakText(
      'Kumusta! Ito ay pagsubok ng ElevenLabs text-to-speech. Kung naririnig ninyo ito, gumagana na ang TTS.',
      voice: _defaultVoiceId,
    );
  }

  /// Dispose of resources
  void dispose() {
    _audioPlayer.dispose();
  }
}
