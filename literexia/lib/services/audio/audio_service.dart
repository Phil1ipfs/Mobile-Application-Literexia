// lib/services/audio_service.dart
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Audio players
  late AudioPlayer _backgroundPlayer;
  late AudioPlayer _sfxPlayer;
  
  // Audio state
  bool _isAudioEnabled = true;
  bool _isBackgroundMusicEnabled = true;
  bool _isSfxEnabled = true;
  bool _isInitialized = false;
  
  // Volume controls
  double _backgroundVolume = 0.3;
  double _sfxVolume = 0.7;
  
  // Getters
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isBackgroundMusicEnabled => _isBackgroundMusicEnabled;
  bool get isSfxEnabled => _isSfxEnabled;
  bool get isInitialized => _isInitialized;
  double get backgroundVolume => _backgroundVolume;
  double get sfxVolume => _sfxVolume;

  // Initialize the audio service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _backgroundPlayer = AudioPlayer();
      _sfxPlayer = AudioPlayer();
      
      // Load saved preferences
      await _loadPreferences();
      
      _isInitialized = true;
      print('Audio service initialized');
    } catch (e) {
      print('Error initializing audio service: $e');
    }
  }

  // Load audio preferences from shared preferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAudioEnabled = prefs.getBool('audio_enabled') ?? true;
      _isBackgroundMusicEnabled = prefs.getBool('background_music_enabled') ?? true;
      _isSfxEnabled = prefs.getBool('sfx_enabled') ?? true;
      _backgroundVolume = prefs.getDouble('background_volume') ?? 0.3;
      _sfxVolume = prefs.getDouble('sfx_volume') ?? 0.7;
      notifyListeners();
    } catch (e) {
      print('Error loading audio preferences: $e');
    }
  }

  // Save audio preferences
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('audio_enabled', _isAudioEnabled);
      await prefs.setBool('background_music_enabled', _isBackgroundMusicEnabled);
      await prefs.setBool('sfx_enabled', _isSfxEnabled);
      await prefs.setDouble('background_volume', _backgroundVolume);
      await prefs.setDouble('sfx_volume', _sfxVolume);
    } catch (e) {
      print('Error saving audio preferences: $e');
    }
  }

  // Toggle all audio
  Future<void> toggleAudio() async {
    _isAudioEnabled = !_isAudioEnabled;
    if (!_isAudioEnabled) {
      await stopBackgroundMusic();
    }
    await _savePreferences();
    notifyListeners();
  }

  // Toggle background music
  Future<void> toggleBackgroundMusic() async {
    _isBackgroundMusicEnabled = !_isBackgroundMusicEnabled;
    if (!_isBackgroundMusicEnabled) {
      await stopBackgroundMusic();
    }
    await _savePreferences();
    notifyListeners();
  }

  // Toggle sound effects
  Future<void> toggleSfx() async {
    _isSfxEnabled = !_isSfxEnabled;
    await _savePreferences();
    notifyListeners();
  }

  // Set background volume
  Future<void> setBackgroundVolume(double volume) async {
    _backgroundVolume = volume.clamp(0.0, 1.0);
    await _backgroundPlayer.setVolume(_backgroundVolume);
    await _savePreferences();
    notifyListeners();
  }

  // Set SFX volume
  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume.clamp(0.0, 1.0);
    await _sfxPlayer.setVolume(_sfxVolume);
    await _savePreferences();
    notifyListeners();
  }

  // Play background music
  Future<void> playBackgroundMusic(String assetPath, {bool loop = true}) async {
    if (!_isInitialized || !_isAudioEnabled || !_isBackgroundMusicEnabled) return;
    
    try {
      await _backgroundPlayer.setAsset(assetPath);
      await _backgroundPlayer.setVolume(_backgroundVolume);
      await _backgroundPlayer.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      await _backgroundPlayer.play();
      print('Playing background music: $assetPath');
    } catch (e) {
      print('Error playing background music: $e');
    }
  }

  // Stop background music
  Future<void> stopBackgroundMusic() async {
    if (!_isInitialized) return;
    
    try {
      await _backgroundPlayer.stop();
      print('Background music stopped');
    } catch (e) {
      print('Error stopping background music: $e');
    }
  }

  // Pause background music
  Future<void> pauseBackgroundMusic() async {
    if (!_isInitialized) return;
    
    try {
      await _backgroundPlayer.pause();
      print('Background music paused');
    } catch (e) {
      print('Error pausing background music: $e');
    }
  }

  // Resume background music
  Future<void> resumeBackgroundMusic() async {
    if (!_isInitialized || !_isAudioEnabled || !_isBackgroundMusicEnabled) return;
    
    try {
      await _backgroundPlayer.play();
      print('Background music resumed');
    } catch (e) {
      print('Error resuming background music: $e');
    }
  }

  // Play sound effect
  Future<void> playSfx(String assetPath) async {
    if (!_isInitialized || !_isAudioEnabled || !_isSfxEnabled) return;
    
    try {
      await _sfxPlayer.setAsset(assetPath);
      await _sfxPlayer.setVolume(_sfxVolume);
      await _sfxPlayer.seek(Duration.zero);
      await _sfxPlayer.play();
      print('Playing SFX: $assetPath');
    } catch (e) {
      print('Error playing SFX: $e');
    }
  }

  // Predefined sound effects
  Future<void> playButtonClick() async {
    await playSfx('assets/audio/button_click.mp3');
  }

  Future<void> playButtonHover() async {
    await playSfx('assets/audio/button_hover.mp3');
  }

  Future<void> playSuccess() async {
    await playSfx('assets/audio/success.mp3');
  }

  Future<void> playError() async {
    await playSfx('assets/audio/error.mp3');
  }

  Future<void> playNotification() async {
    await playSfx('assets/audio/notification.mp3');
  }

  // Cleanup
  Future<void> dispose() async {
    try {
      await _backgroundPlayer.dispose();
      await _sfxPlayer.dispose();
      print('Audio service disposed');
    } catch (e) {
      print('Error disposing audio service: $e');
    }
  }
}