import 'package:just_audio/just_audio.dart';

/// Centralized service to handle background music across the app
/// Prevents music duplication by ensuring only one instance plays at a time
class BackgroundMusicService {
  static final BackgroundMusicService _instance = BackgroundMusicService._internal();
  factory BackgroundMusicService() => _instance;
  BackgroundMusicService._internal();

  static AudioPlayer? _backgroundMusicPlayer;
  static bool _isPlaying = false;
  static String? _currentTrack;

  /// Start background music, automatically stopping any existing music
  static Future<void> startBackgroundMusic({String track = 'assets/audio/homeBg.mp3', double volume = 0.5}) async {
    try {
      // Stop any existing background music first
      await stopBackgroundMusic();

      // Create new player instance
      _backgroundMusicPlayer = AudioPlayer();

      await _backgroundMusicPlayer!.setAsset(track);
      await _backgroundMusicPlayer!.setVolume(volume);
      await _backgroundMusicPlayer!.setLoopMode(LoopMode.one);
      await _backgroundMusicPlayer!.play();

      _isPlaying = true;
      _currentTrack = track;

      print('[BackgroundMusicService] Started background music: $track');
    } catch (e) {
      print('[BackgroundMusicService] Error starting background music: $e');
    }
  }

  /// Stop background music
  static Future<void> stopBackgroundMusic() async {
    try {
      if (_backgroundMusicPlayer != null) {
        await _backgroundMusicPlayer!.stop();
        await _backgroundMusicPlayer!.dispose();
        _backgroundMusicPlayer = null;
        _isPlaying = false;
        _currentTrack = null;
        print('[BackgroundMusicService] Stopped background music');
      }
    } catch (e) {
      print('[BackgroundMusicService] Error stopping background music: $e');
    }
  }

  /// Pause background music
  static Future<void> pauseBackgroundMusic() async {
    try {
      if (_backgroundMusicPlayer != null && _isPlaying) {
        await _backgroundMusicPlayer!.pause();
        print('[BackgroundMusicService] Paused background music');
      }
    } catch (e) {
      print('[BackgroundMusicService] Error pausing background music: $e');
    }
  }

  /// Resume background music
  static Future<void> resumeBackgroundMusic() async {
    try {
      if (_backgroundMusicPlayer != null && !_isPlaying) {
        await _backgroundMusicPlayer!.play();
        print('[BackgroundMusicService] Resumed background music');
      }
    } catch (e) {
      print('[BackgroundMusicService] Error resuming background music: $e');
    }
  }

  /// Set volume for background music
  static Future<void> setVolume(double volume) async {
    try {
      if (_backgroundMusicPlayer != null) {
        await _backgroundMusicPlayer!.setVolume(volume);
      }
    } catch (e) {
      print('[BackgroundMusicService] Error setting volume: $e');
    }
  }

  /// Check if background music is playing
  static bool get isPlaying => _isPlaying && _backgroundMusicPlayer != null;

  /// Get current track
  static String? get currentTrack => _currentTrack;

  /// Dispose all resources (call this when app is closing)
  static Future<void> dispose() async {
    await stopBackgroundMusic();
  }
}