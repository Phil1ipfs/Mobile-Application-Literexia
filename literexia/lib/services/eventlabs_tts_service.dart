// lib/services/eventlabs_tts_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/timeout_config.dart';
import 'credential_service.dart';

/// ElevenLabs Text-to-Speech Service
///
/// This service handles text-to-speech functionality using ElevenLabs API
class EventLabsTTSService {
  static String? _apiKey;
  static const String _baseUrl = 'https://api.elevenlabs.io/v1';
  static const String _defaultVoiceId = 'P1hTNpVDMG973fukK9V2'; // ate Ada voice

  /// Initialize the service with secure credentials
  static Future<void> initialize() async {
    try {
      // Initialize credential service
      final credentialService = CredentialService();
      await credentialService.initialize();

      // Get API key securely
      _apiKey = await credentialService.getCredential('ELEVENLABS_API_KEY');

      print('[EventLabsTTSService] ✅ Initialized with secure credentials');
    } catch (e) {
      print('[EventLabsTTSService] ❌ Failed to initialize: $e');
      throw Exception('Failed to initialize TTS service with secure credentials: $e');
    }
  }

  /// Get the API key (for internal use only)
  static String get apiKey {
    if (_apiKey == null) {
      throw Exception('EventLabsTTSService not initialized. Call initialize() first.');
    }
    return _apiKey!;
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  // Cache for audio files
  static final Map<String, String> _audioCache = {};
  static late Directory _cacheDir;
  static bool _cacheInitialized = false;

  // HTTP client for connection reuse
  static final http.Client _httpClient = http.Client();

  // Getters
  bool get isPlaying => _isPlaying;
  bool get isAvailable =>
      true; // EventLabs API is always available if properly configured

  /// Initialize cache directory
  Future<void> _initializeCache() async {
    if (_cacheInitialized) return;

    try {
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/tts_cache');
      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }
      _cacheInitialized = true;
    } catch (e) {
      print('Failed to initialize TTS cache: $e');
    }
  }

  /// Generate cache key for text and voice combination
  String _generateCacheKey(String text, String voiceId) {
    final combined = '$text|$voiceId';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get cached audio file path if exists
  Future<String?> _getCachedAudio(String text, String voiceId) async {
    await _initializeCache();

    final cacheKey = _generateCacheKey(text, voiceId);
    final cachedPath = _audioCache[cacheKey];

    if (cachedPath != null && await File(cachedPath).exists()) {
      return cachedPath;
    }

    return null;
  }

  /// Save audio to cache
  Future<String> _saveToCache(String text, String voiceId, Uint8List audioData) async {
    await _initializeCache();

    final cacheKey = _generateCacheKey(text, voiceId);
    final audioFile = File('${_cacheDir.path}/$cacheKey.mp3');

    await audioFile.writeAsBytes(audioData);
    _audioCache[cacheKey] = audioFile.path;

    return audioFile.path;
  }

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

      // Check cache first for faster playback
      String? audioFilePath = await _getCachedAudio(text, voiceId);

      if (audioFilePath == null) {
        // Not in cache, make API request to ElevenLabs with timeout
        final response = await TimeoutConfig.withRetry(
          () => _httpClient.post(
            Uri.parse('$_baseUrl/text-to-speech/$voiceId'),
            headers: {
              'xi-api-key': apiKey,
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
          ),
          timeout: TimeoutConfig.tts,
          operationName: 'TTS API Request',
          maxAttempts: 2,
          shouldRetry: TimeoutConfig.isRetryableError,
        );

        if (response.statusCode == 200) {
          // Save audio data to cache
          audioFilePath = await _saveToCache(text, voiceId, response.bodyBytes);
        } else {
          print(
              'ElevenLabs TTS API error: ${response.statusCode} - ${response.body}');
          _isPlaying = false;
          if (onError != null) onError();
          return false;
        }
      }

      // Play the audio file (either from cache or newly generated)
      await _audioPlayer.setFilePath(audioFilePath);

      // Preload and start playback immediately for better performance
      await _audioPlayer.load();
      await _audioPlayer.play();

      // Wait for playback to complete
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          if (onComplete != null) onComplete();
        }
      });

      return true;
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
      final response = await TimeoutConfig.withTimeout(
        _httpClient.get(
          Uri.parse('$_baseUrl/voices'),
          headers: {
            'xi-api-key': apiKey,
          },
        ),
        timeout: TimeoutConfig.standard,
        operationName: 'Get TTS Voices',
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

  /// Preload common phrases to cache for faster playback
  Future<void> preloadCommonPhrases() async {
    final commonPhrases = [
      'Magandang umaga!',
      'Magandang hapon!',
      'Magandang gabi!',
      'Kumusta!',
      'Salamat!',
      'Tama!',
      'Mali!',
      'Mali!',
      'Mahusay!',
      'Patuloy lang!',
      'Basahin mo ang salitang ito',
      'Piliin ang tamang sagot',
      'Pakinggan ang tunog ng salita',
      'Ulitin mo ang pagbasa',
      'Nakakatuwa!',
    ];

    await preloadPhrases(commonPhrases);
  }

  /// Preload arbitrary phrases into the cache (no playback) so later playback
  /// is instant. Skips phrases already cached. Safe to call in the background.
  Future<void> preloadPhrases(List<String> phrases) async {
    for (final phrase in phrases) {
      if (phrase.trim().isEmpty) continue;
      try {
        // Skip if already cached to avoid a redundant API call
        if (await _getCachedAudio(phrase, _defaultVoiceId) != null) continue;

        final response = await TimeoutConfig.withTimeout(
          _httpClient.post(
            Uri.parse('$_baseUrl/text-to-speech/$_defaultVoiceId'),
            headers: {
              'xi-api-key': apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'text': phrase,
              'model_id': 'eleven_multilingual_v2',
              'voice_settings': {
                'stability': 0.5,
                'similarity_boost': 0.75,
                'style': 0.0,
                'use_speaker_boost': true
              }
            }),
          ),
          timeout: TimeoutConfig.tts,
          operationName: 'Preload TTS Phrase',
        );

        if (response.statusCode == 200) {
          await _saveToCache(phrase, _defaultVoiceId, response.bodyBytes);
          print('Preloaded: "$phrase"');
        }
      } catch (e) {
        print('Failed to preload "$phrase": $e');
      }
    }
  }

  /// Test the TTS service with a sample text
  Future<bool> testTTS() async {
    return await speakText(
      'Kumusta! Ito ay pagsubok ng ElevenLabs text-to-speech. Kung naririnig ninyo ito, gumagana na ang TTS.',
      voice: _defaultVoiceId,
    );
  }

  /// Clear cache to free up storage
  Future<void> clearCache() async {
    try {
      if (_cacheInitialized && await _cacheDir.exists()) {
        await _cacheDir.delete(recursive: true);
        _audioCache.clear();
        _cacheInitialized = false;
      }
    } catch (e) {
      print('Failed to clear TTS cache: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _audioPlayer.dispose();
    _httpClient.close();
  }
}
