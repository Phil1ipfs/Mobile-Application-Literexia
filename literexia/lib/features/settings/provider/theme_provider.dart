// lib/features/settings/logic/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/playai_tts_service.dart';

class AppThemeData {
  final String name;
  final Color primaryColor; // Main background color
  final Color headerColor; // Header/appbar color (slightly darker)
  final Color accentColor; // Button and highlight color
  final Color textColor; // Primary text color
  final Color buttonTextColor; // Text color on buttons

  const AppThemeData({
    required this.name,
    required this.primaryColor,
    Color? headerColor,
    required this.accentColor,
    required this.textColor,
    required this.buttonTextColor,
  }) : headerColor = headerColor ?? primaryColor;
}

class ThemeProvider extends ChangeNotifier {
  // Available themes
  static const List<AppThemeData> availableThemes = [
    // Yellow theme
    AppThemeData(
      name: 'Yellow',
      primaryColor: Colors.black,
      headerColor: Color(0xFF121212),
      accentColor: Color(0xFFFFD700), // Gold/Yellow
      textColor: Colors.white,
      buttonTextColor: Colors.black,
    ),

    // Red theme
    AppThemeData(
      name: 'Red',
      primaryColor: Color(0xFF444444), // Dark gray
      headerColor: Color(0xFF333333),
      accentColor: Color(0xFFFF5252), // Red
      textColor: Colors.white,
      buttonTextColor: Colors.white,
    ),

    // Orange theme
    AppThemeData(
      name: 'Orange',
      primaryColor: Color(0xFF444444), // Dark gray
      headerColor: Color(0xFF333333),
      accentColor: Color(0xFFFF9800), // Orange
      textColor: Colors.white,
      buttonTextColor: Colors.black,
    ),

    // Black theme
    AppThemeData(
      name: 'Black',
      primaryColor: Colors.white,
      headerColor: Color(0xFFF5F5F5),
      accentColor: Colors.black,
      textColor: Colors.black,
      buttonTextColor: Colors.white,
    ),

    // Blue theme
    AppThemeData(
      name: 'Blue',
      primaryColor: Color(0xFF334970), // Dark blue
      headerColor: Color(0xFF263352), // Slightly darker blue
      accentColor: Color(0xFFFFD700), // Gold/Yellow
      textColor: Colors.white,
      buttonTextColor: Colors.black,
    ),
  ];

  // Default settings
  int _currentThemeIndex = 4; // Start with blue theme
  bool _textToSpeechEnabled = false;
  double _textSize = 0.5; // 0.0-1.0
  double _readingSpeed = 0.5; // 0.0-1.0
  double _letterSpacing = 0.0; // 0.0-1.0
  String _fontFamily = 'Century Gothic';

  // Available fonts
  final List<String> _availableFonts = [
    'Century Gothic',
    'OpenDyslexic',
    'Arial',
    'Comic Sans MS',
    'Verdana',
  ];

  // TTS Service integration
  final PlayAITTSService _ttsService = PlayAITTSService.instance;

  // Getters
  AppThemeData get currentTheme => availableThemes[_currentThemeIndex];
  bool get textToSpeechEnabled => _textToSpeechEnabled;
  double get textSize => _textSize;
  double get readingSpeed => _readingSpeed;
  double get letterSpacing => _letterSpacing;
  String get fontFamily => _fontFamily;
  List<String> get availableFonts => _availableFonts;

  // TTS Status getters
  bool get isSpeaking => _ttsService.isPlaying;
  bool get isTTSLoading => _ttsService.isLoading;

  // Constructor - Load settings from SharedPreferences
  ThemeProvider() {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load theme index
      _currentThemeIndex =
          prefs.getInt('themeIndex') ?? 4; // Default to blue theme
      if (_currentThemeIndex >= availableThemes.length) {
        _currentThemeIndex = 4;
      }

      // Load text-to-speech setting
      _textToSpeechEnabled = prefs.getBool('textToSpeechEnabled') ?? false;

      // Load text size
      _textSize = prefs.getDouble('textSize') ?? 0.5;

      // Load reading speed
      _readingSpeed = prefs.getDouble('readingSpeed') ?? 0.5;

      // Load letter spacing
      _letterSpacing = prefs.getDouble('letterSpacing') ?? 0.0;

      // Load font family
      _fontFamily = prefs.getString('fontFamily') ?? 'Century Gothic';

      notifyListeners();
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  // Save settings to SharedPreferences
  Future<bool> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save theme index
      await prefs.setInt('themeIndex', _currentThemeIndex);

      // Save text-to-speech setting
      await prefs.setBool('textToSpeechEnabled', _textToSpeechEnabled);

      // Save text size
      await prefs.setDouble('textSize', _textSize);

      // Save reading speed
      await prefs.setDouble('readingSpeed', _readingSpeed);

      // Save letter spacing
      await prefs.setDouble('letterSpacing', _letterSpacing);

      // Save font family
      await prefs.setString('fontFamily', _fontFamily);

      notifyListeners();
      return true;
    } catch (e) {
      print('Error saving settings: $e');
      return false;
    }
  }

  // Change theme by index
  void setThemeByIndex(int index) {
    if (index >= 0 && index < availableThemes.length) {
      _currentThemeIndex = index;
      notifyListeners();
    }
  }

  // Change theme by color
  void setThemeByColor(Color color) {
    for (int i = 0; i < availableThemes.length; i++) {
      if (availableThemes[i].accentColor == color) {
        _currentThemeIndex = i;
        notifyListeners();
        break;
      }
    }
  }

  // Setters for other settings
  void setTextToSpeechEnabled(bool value) {
    _textToSpeechEnabled = value;
    if (!value) {
      // Stop any currently playing TTS
      _ttsService.stop();
    }
    notifyListeners();
  }

  void setTextSize(double value) {
    _textSize = value;
    notifyListeners();
  }

  void setReadingSpeed(double value) {
    _readingSpeed = value;
    notifyListeners();
  }

  void setLetterSpacing(double value) {
    _letterSpacing = value;
    notifyListeners();
  }

  void setFontFamily(String value) {
    if (_availableFonts.contains(value)) {
      _fontFamily = value;
      notifyListeners();
    }
  }

  // TTS Integration Methods
  Future<bool> speakText(String text, {
    bool cache = true,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    if (!_textToSpeechEnabled) {
      print('TTS is disabled');
      onComplete?.call();
      return false;
    }

    return await _ttsService.speak(
      text,
      cache: cache,
      onStart: onStart,
      onComplete: onComplete,
      onError: onError,
    );
  }

  Future<void> stopSpeaking() async {
    await _ttsService.stop();
  }

  Future<void> pauseSpeaking() async {
    await _ttsService.pause();
  }

  Future<void> resumeSpeaking() async {
    await _ttsService.resume();
  }

  // Check if TTS service is available
  Future<bool> checkTTSAvailability() async {
    return await _ttsService.isAvailable();
  }

  // Clear TTS cache
  Future<void> clearTTSCache() async {
    await _ttsService.clearCache();
  }

  // Utility functions for converting settings to actual values
  double getRealFontSize(double baseSize) {
    // Map slider value (0.0-1.0) to font size multiplier (0.8-1.5)
    double multiplier = 0.8 + (_textSize * 0.7);
    return baseSize * multiplier;
  }

  double getRealLetterSpacing() {
    // Map slider value (0.0-1.0) to letter spacing (0.0-3.0)
    return _letterSpacing * 3.0;
  }

  // Get reading speed for TTS (maps slider to actual playback speed)
  double getTTSSpeed() {
    // Map slider value (0.0-1.0) to TTS speed (0.5-2.0)
    return 0.5 + (_readingSpeed * 1.5);
  }

  // Get ThemeData for MaterialApp
  ThemeData getThemeData() {
    final theme = currentTheme;

    return ThemeData(
      primaryColor: theme.primaryColor,
      scaffoldBackgroundColor: theme.primaryColor,
      appBarTheme: AppBarTheme(
        backgroundColor: theme.headerColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textColor),
        titleTextStyle: TextStyle(
          color: theme.textColor,
          fontSize: getRealFontSize(20),
          fontFamily: _fontFamily,
          letterSpacing: getRealLetterSpacing(),
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: theme.textColor,
          fontSize: getRealFontSize(32),
          fontFamily: _fontFamily,
          letterSpacing: getRealLetterSpacing(),
        ),
        displayMedium: TextStyle(
          color: theme.textColor,
          fontSize: getRealFontSize(24),
          fontFamily: _fontFamily,
          letterSpacing: getRealLetterSpacing(),
        ),
        bodyLarge: TextStyle(
          color: theme.textColor,
          fontSize: getRealFontSize(16),
          fontFamily: _fontFamily,
          letterSpacing: getRealLetterSpacing(),
        ),
        bodyMedium: TextStyle(
          color: theme.textColor,
          fontSize: getRealFontSize(14),
          fontFamily: _fontFamily,
          letterSpacing: getRealLetterSpacing(),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.accentColor,
          foregroundColor: theme.buttonTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: getRealFontSize(16),
            letterSpacing: getRealLetterSpacing(),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.textColor,
          side: BorderSide(color: theme.accentColor, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: getRealFontSize(16),
            letterSpacing: getRealLetterSpacing(),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      iconTheme: IconThemeData(color: theme.textColor),
      sliderTheme: SliderThemeData(
        activeTrackColor: theme.accentColor,
        thumbColor: theme.accentColor,
        inactiveTrackColor: theme.accentColor.withOpacity(0.3),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return theme.accentColor;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return theme.accentColor.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.5);
        }),
      ),
      fontFamily: _fontFamily,
      // Make sure bottom navigation uses theme colors
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: theme.headerColor,
        selectedItemColor: theme.accentColor,
        unselectedItemColor: theme.textColor.withOpacity(0.7),
      ),
      // Make sure text field colors are themed
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: theme.accentColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: theme.accentColor, width: 2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }
}