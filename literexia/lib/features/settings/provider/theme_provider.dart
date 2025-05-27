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
  // Available themes
  static final List<AppThemeData> availableThemes = [
    AppThemeData(
      name: 'Blue',
      primaryColor: const Color(0xFF283A5B),
      headerColor: const Color(0xFF1D2B45),
      accentColor: const Color(0xFF55AAFF),
      textColor: Colors.white,
      buttonTextColor: Colors.white,
    ),
    AppThemeData(
      name: 'Green',
      primaryColor: const Color(0xFF1F3A20),
      headerColor: const Color(0xFF15291B),
      accentColor: const Color(0xFF4CAF50),
      textColor: Colors.white,
      buttonTextColor: Colors.white,
    ),
    AppThemeData(
      name: 'Purple',
      primaryColor: const Color(0xFF3A1F59),
      headerColor: const Color(0xFF29153E),
      accentColor: const Color(0xFF9C27B0),
      textColor: Colors.white,
      buttonTextColor: Colors.white,
    ),
    AppThemeData(
      name: 'Orange',
      primaryColor: const Color(0xFF3A2A1F),
      headerColor: const Color(0xFF291F15),
      accentColor: const Color(0xFFFF9800),
      textColor: Colors.white,
      buttonTextColor: Colors.white,
    ),
    AppThemeData(
      name: 'Red',
      primaryColor: const Color(0xFF3A1F1F),
      headerColor: const Color(0xFF291515),
      accentColor: const Color(0xFFF44336),
      textColor: Colors.white,
      buttonTextColor: Colors.white,
    ),
  ];

  // Current theme - default to first one
  AppThemeData _currentTheme = availableThemes[0];
  
  // Font preferences
  String _fontFamily = 'BubblegumSans';
  double _textSize = 0.5; // Default text size (0.0 to 1.0)
  double _letterSpacing = 0.0; // Default letter spacing (0.0 to 1.0)
  double _readingSpeed = 0.5; // Default reading speed (0.0 to 1.0)
  
  // Available fonts
  final List<String> _availableFonts = [
    'BubblegumSans',
    'Roboto',
    'OpenSans',
    'Montserrat',
    'Poppins',
  ];
  
  // TTS provider reference
  TTSProvider? _ttsProvider;
  bool _textToSpeechEnabled = true;

  // Getters
  AppThemeData get currentTheme => _currentTheme;
  String get fontFamily => _fontFamily;
  double get textSize => _textSize;
  double get letterSpacing => _letterSpacing;
  double get readingSpeed => _readingSpeed;
  List<String> get availableFonts => _availableFonts;
  bool get textToSpeechEnabled => _textToSpeechEnabled && (_ttsProvider?.isAvailable ?? false);

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
      
      // Load theme
      final themeName = prefs.getString('theme_name');
      if (themeName != null) {
        setThemeByName(themeName);
      }
      
      // Load font
      final fontFamily = prefs.getString('font_family');
      if (fontFamily != null && _availableFonts.contains(fontFamily)) {
        _fontFamily = fontFamily;
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
  
  // Save settings to shared preferences
  Future<bool> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save theme
      await prefs.setString('theme_name', _currentTheme.name);
      
      // Save font
      await prefs.setString('font_family', _fontFamily);
      
      // Save text size
      await prefs.setDouble('text_size', _textSize);
      
      // Save letter spacing
      await prefs.setDouble('letter_spacing', _letterSpacing);
      
      // Save reading speed
      await prefs.setDouble('reading_speed', _readingSpeed);
      
      // Save TTS enabled state
      await prefs.setBool('tts_enabled', _textToSpeechEnabled);
      
      return true;
    } catch (e) {
      print('Error saving settings: $e');
      return false;
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
  
  // Set theme
  void setTheme(AppThemeData theme) {
    _currentTheme = theme;
    notifyListeners();
  }
  
  // Set font family
  void setFontFamily(String fontFamily) {
    if (_availableFonts.contains(fontFamily)) {
      _fontFamily = fontFamily;
      notifyListeners();
    }
  }
  
  // Set text size
  void setTextSize(double value) {
    _textSize = value;
    notifyListeners();
  }
  
  // Set letter spacing
  void setLetterSpacing(double value) {
    _letterSpacing = value;
    notifyListeners();
  }
  
  // Set reading speed
  void setReadingSpeed(double value) {
    _readingSpeed = value;
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
    if (_ttsProvider == null || !_textToSpeechEnabled || !_ttsProvider!.isAvailable) {
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