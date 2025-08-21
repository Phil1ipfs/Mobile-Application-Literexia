// lib/features/settings/provider/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart';

// Class to hold theme data
class AppThemeData {
  final String name;
  final Color primaryColor;
  final Color headerColor;
  final Color accentColor;
  final Color textColor;
  final Color buttonTextColor;

  const AppThemeData({
    required this.name,
    required this.primaryColor,
    required this.headerColor,
    required this.accentColor,
    required this.textColor,
    required this.buttonTextColor,
  });
}

class ThemeProvider extends ChangeNotifier {
  // Available themes with specified colors - Removed Black theme (4th option)
  static final List<AppThemeData> availableThemes = [
    AppThemeData(
      name: 'Blue',
      primaryColor: const Color(0xFF1B2A4F),
      headerColor: const Color(0xFF1B2A4F),
      accentColor: const Color(0xFF1B2A4F),
      textColor: Colors.white,
      buttonTextColor: Colors.white,
    ),
    AppThemeData(
      name: 'Red',
      primaryColor: const Color(0xFF3A1F1F),
      headerColor: const Color(0xFF291515),
      accentColor: const Color(0xFFF7574A),
      textColor: Colors.white,
      buttonTextColor: Colors.white,
    ),
    AppThemeData(
      name: 'Orange',
      primaryColor: const Color(0xFF3A2A1F),
      headerColor: const Color(0xFF291F15),
      accentColor: const Color(0xFFF37423),
      textColor: Colors.white,
      buttonTextColor: Colors.white,
    ),
    AppThemeData(
      name: 'White',
      primaryColor: const Color(0xFFFFFFFF), // White background
      headerColor: const Color(0xFFF5F5F5), // Light gray header
      accentColor: const Color(0xFF000000), // Black buttons/accents
      textColor: Colors.black, // Black text on white background
      buttonTextColor: Colors.white, // White text on black buttons
    ),
  ];

  // Current theme - default to blue theme (#1B2A4F)
  AppThemeData _currentTheme =
      availableThemes[0]; // Blue theme as default (index 0)

  // Temporary theme settings (not saved until saveSettings is called)
  AppThemeData? _tempTheme;

  // Font preferences - UPDATED: Century Gothic as default
  String _fontFamily = 'Century Gothic';
  String? _tempFontFamily; // Temporary font selection
  double _textSize = 0.5; // Default text size (0.0 to 1.0)
  double? _tempTextSize; // Temporary text size
  double _letterSpacing = 0.0; // Default letter spacing (0.0 to 1.0)
  double? _tempLetterSpacing; // Temporary letter spacing
  double _readingSpeed = 0.5; // Default reading speed (0.0 to 1.0)
  double? _tempReadingSpeed; // Temporary reading speed

  // Available fonts - Only Century Gothic and Open Dyslexic
  final List<String> _availableFonts = [
    'Century Gothic', // Default font - listed first
    'Open Dyslexic', // Accessibility font for dyslexia
  ];

  // TTS provider reference
  TTSProvider? _ttsProvider;
  bool _textToSpeechEnabled = true;

  // Getters - return temporary values if they exist, otherwise return saved values
  AppThemeData get currentTheme => _tempTheme ?? _currentTheme;
  String get fontFamily => _tempFontFamily ?? _fontFamily;
  double get textSize => _tempTextSize ?? _textSize;
  double get letterSpacing => _tempLetterSpacing ?? _letterSpacing;
  double get readingSpeed => _tempReadingSpeed ?? _readingSpeed;
  List<String> get availableFonts => _availableFonts;
  bool get textToSpeechEnabled =>
      _textToSpeechEnabled && (_ttsProvider?.isAvailable ?? false);

  // Constructor loads saved settings
  ThemeProvider() {
    _loadSettings();
  }

  // Set TTS provider
  void setTTSProvider(TTSProvider provider) {
    _ttsProvider = provider;
    notifyListeners();
  }

  // Load settings from shared preferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load theme - Default to Blue if no saved theme
      final themeName = prefs.getString('theme_name');
      if (themeName != null) {
        final theme = availableThemes.firstWhere(
          (theme) => theme.name == themeName,
          orElse: () => availableThemes[0], // Default to Blue
        );
        _currentTheme = theme; // Set actual theme, not temp
      } else {
        // If no saved theme, use blue as default
        _currentTheme = availableThemes[0]; // Blue theme
      }

      // Load font - UPDATED: Handle migration from old fonts to new default
      final fontFamily = prefs.getString('font_family');
      if (fontFamily != null && _availableFonts.contains(fontFamily)) {
        _fontFamily = fontFamily;
      } else {
        // If no saved font or saved font is not available, use default
        _fontFamily = 'Century Gothic';
      }

      // Load text size
      final textSize = prefs.getDouble('text_size');
      if (textSize != null) {
        _textSize = textSize;
      }

      // Load letter spacing
      final letterSpacing = prefs.getDouble('letter_spacing');
      if (letterSpacing != null) {
        _letterSpacing = letterSpacing;
      }

      // Load reading speed
      final readingSpeed = prefs.getDouble('reading_speed');
      if (readingSpeed != null) {
        _readingSpeed = readingSpeed;
      }

      // Load TTS enabled state
      final ttsEnabled = prefs.getBool('tts_enabled');
      if (ttsEnabled != null) {
        _textToSpeechEnabled = ttsEnabled;
      }

      notifyListeners();
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  // Save settings to shared preferences and apply temporary changes
  Future<bool> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Apply temporary changes to actual settings
      if (_tempTheme != null) {
        _currentTheme = _tempTheme!;
        _tempTheme = null;
      }
      if (_tempFontFamily != null) {
        _fontFamily = _tempFontFamily!;
        _tempFontFamily = null;
      }
      if (_tempTextSize != null) {
        _textSize = _tempTextSize!;
        _tempTextSize = null;
      }
      if (_tempLetterSpacing != null) {
        _letterSpacing = _tempLetterSpacing!;
        _tempLetterSpacing = null;
      }
      if (_tempReadingSpeed != null) {
        _readingSpeed = _tempReadingSpeed!;
        _tempReadingSpeed = null;
      }

      // Save to SharedPreferences
      await prefs.setString('theme_name', _currentTheme.name);
      await prefs.setString('font_family', _fontFamily);
      await prefs.setDouble('text_size', _textSize);
      await prefs.setDouble('letter_spacing', _letterSpacing);
      await prefs.setDouble('reading_speed', _readingSpeed);
      await prefs.setBool('tts_enabled', _textToSpeechEnabled);

      notifyListeners();
      return true;
    } catch (e) {
      print('Error saving settings: $e');
      return false;
    }
  }

  // Discard temporary changes and revert to saved settings
  void discardChanges() {
    _tempTheme = null;
    _tempFontFamily = null;
    _tempTextSize = null;
    _tempLetterSpacing = null;
    _tempReadingSpeed = null;
    notifyListeners();
  }

  // Check if a route should use dynamic themes
  static bool shouldUseThemes(String? routeName) {
    const themeEnabledRoutes = {
      '/home',
      '/profile',
      '/settings',
      '/user-management',
      '/assessment',
      '/student-reflect',
    };

    return routeName != null && themeEnabledRoutes.contains(routeName);
  }

  // Get theme data with route-based condition
  ThemeData getThemeDataForRoute(String? routeName) {
    if (shouldUseThemes(routeName)) {
      return getThemeData(); // Use dynamic theme
    } else {
      // Return default blue theme for non-themed routes
      return ThemeData(
        primaryColor: const Color(0xFF2E3C5A),
        scaffoldBackgroundColor: const Color(0xFF2E3C5A),
        fontFamily: 'Century Gothic',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            fontSize: 16,
            letterSpacing: 0.0,
            fontFamily: 'Century Gothic',
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            letterSpacing: 0.0,
            fontFamily: 'Century Gothic',
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            letterSpacing: 0.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'Century Gothic',
          ),
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF55AAFF),
          secondary: const Color(0xFF55AAFF),
        ),
      );
    }
  }

  // Set theme by name
  void setThemeByName(String name) {
    final theme = availableThemes.firstWhere(
      (theme) => theme.name == name,
      orElse: () => availableThemes[0],
    );
    setTheme(theme);
  }

  // Set theme by index
  void setThemeByIndex(int index) {
    if (index >= 0 && index < availableThemes.length) {
      setTheme(availableThemes[index]);
    }
  }

  // Set theme - stores as temporary until saved
  void setTheme(AppThemeData theme) {
    _tempTheme = theme;
    notifyListeners();
  }

  // Set font family - stores as temporary until saved
  void setFontFamily(String fontFamily) {
    if (_availableFonts.contains(fontFamily)) {
      _tempFontFamily = fontFamily;
      notifyListeners();
    } else {
      // Fallback to default if invalid font is provided
      print(
          'Warning: Font "$fontFamily" not available, using default Century Gothic');
      _tempFontFamily = 'Century Gothic';
      notifyListeners();
    }
  }

  // Set text size - stores as temporary until saved
  void setTextSize(double value) {
    _tempTextSize = value;
    notifyListeners();
  }

  // Set letter spacing - stores as temporary until saved
  void setLetterSpacing(double value) {
    _tempLetterSpacing = value;
    notifyListeners();
  }

  // Set reading speed - stores as temporary until saved
  void setReadingSpeed(double value) {
    _tempReadingSpeed = value;
    notifyListeners();
  }

  // Get actual font size based on slider value
  double getRealFontSize(double baseSize) {
    // Map slider value (0.0-1.0) to size multiplier (0.8-1.5)
    final multiplier = 0.8 + (_textSize * 0.7);
    return baseSize * multiplier;
  }

  // Get actual letter spacing based on slider value
  double getRealLetterSpacing() {
    // Map slider value (0.0-1.0) to spacing (0.0-3.0)
    return _letterSpacing * 3.0;
  }

  // Get reading speed for TTS
  double getTTSSpeed() {
    // Convert reading speed slider (0.0-1.0) to TTS speed range (0.7-1.3)
    return 0.7 + (_readingSpeed * 0.6);
  }

  // Get theme data for MaterialApp
  ThemeData getThemeData() {
    return ThemeData(
      primaryColor: _currentTheme.primaryColor,
      scaffoldBackgroundColor: _currentTheme.primaryColor,
      fontFamily: _fontFamily,
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          fontSize: getRealFontSize(16),
          letterSpacing: getRealLetterSpacing(),
        ),
        bodyMedium: TextStyle(
          fontSize: getRealFontSize(14),
          letterSpacing: getRealLetterSpacing(),
        ),
        titleLarge: TextStyle(
          fontSize: getRealFontSize(22),
          letterSpacing: getRealLetterSpacing(),
          fontWeight: FontWeight.bold,
        ),
      ),
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: _currentTheme.accentColor,
        secondary: _currentTheme.accentColor,
      ),
    );
  }

  // Speak text with TTS
  Future<bool> speakText(
    String text, {
    bool cache = true,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    if (_ttsProvider == null ||
        !_textToSpeechEnabled ||
        !_ttsProvider!.isAvailable) {
      if (onError != null) onError();
      return false;
    }

    return await _ttsProvider!.speakText(
      text,
      voice: 'jaro-conversational', // Default voice
      speed: getTTSSpeed(),
      onStart: onStart,
      onComplete: onComplete,
      onError: onError,
    );
  }

  // Stop speaking
  Future<void> stopSpeaking() async {
    if (_ttsProvider != null) {
      await _ttsProvider!.stopSpeaking();
    }
  }
}
