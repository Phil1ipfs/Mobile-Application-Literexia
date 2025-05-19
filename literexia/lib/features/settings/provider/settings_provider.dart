// lib/features/settings/logic/settings_provider.dart
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

class ThemeColor {
  final String name;
  final Color color;
  final Color textColor;

  ThemeColor({
    required this.name,
    required this.color,
    required this.textColor,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemeColor && other.color == color;
  }

  @override
  int get hashCode => color.hashCode;
}

class SettingsProvider extends ChangeNotifier {
  // Default settings
  bool _isDarkMode = true;
  bool _textToSpeechEnabled = false;
  double _textSize = 0.5; // Value between 0 and 1
  double _readingSpeed = 0.5; // Value between 0 and 1
  double _letterSpacing = 0.0; // Value between 0 and 1
  String _fontFamily = 'Century Gothic';

  // Theme colors
  ThemeColor _themeColor = ThemeColor(
    name: 'Blue',
    color: const Color(0xFF334970),
    textColor: Colors.white,
  );

  // Available fonts
  final List<String> _availableFonts = [
    'Century Gothic',
    'OpenDyslexic',
    'Arial',
    'Comic Sans MS',
    'Verdana',
  ];

  // Getters
  bool get isDarkMode => _isDarkMode;
  bool get textToSpeechEnabled => _textToSpeechEnabled;
  double get textSize => _textSize;
  double get readingSpeed => _readingSpeed;
  double get letterSpacing => _letterSpacing;
  String get fontFamily => _fontFamily;
  ThemeColor get themeColor => _themeColor;
  List<String> get availableFonts => _availableFonts;

  // Constructor - Load settings from SharedPreferences
  SettingsProvider() {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load dark mode setting
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;

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

      // Load theme color (store as name string)
      final themeName = prefs.getString('themeColorName') ?? 'Blue';
      if (themeName == 'White') {
        _themeColor = ThemeColor(
          name: 'White',
          color: Colors.white,
          textColor: Colors.black,
        );
      } else if (themeName == 'Red') {
        _themeColor = ThemeColor(
          name: 'Red',
          color: Colors.red,
          textColor: Colors.white,
        );
      } else if (themeName == 'Orange') {
        _themeColor = ThemeColor(
          name: 'Orange',
          color: Colors.orange,
          textColor: Colors.white,
        );
      } else if (themeName == 'Black') {
        _themeColor = ThemeColor(
          name: 'Black',
          color: Colors.black,
          textColor: Colors.white,
        );
      } else {
        _themeColor = ThemeColor(
          name: 'Blue',
          color: const Color(0xFF334970),
          textColor: Colors.white,
        );
      }

      notifyListeners();
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  // Save settings to SharedPreferences
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save dark mode setting
      await prefs.setBool('isDarkMode', _isDarkMode);

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

      // Save theme color name
      await prefs.setString('themeColorName', _themeColor.name);

      print('Settings saved successfully');
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  // Setters
  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void setTextToSpeechEnabled(bool value) {
    _textToSpeechEnabled = value;
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

  void setThemeColor(ThemeColor color) {
    _themeColor = color;
    notifyListeners();
  }

  // Get real font size based on slider value
  double getRealFontSize(double baseSize) {
    // Map slider value (0.0-1.0) to font size multiplier (0.8-1.5)
    double multiplier = 0.8 + (_textSize * 0.7);
    return baseSize * multiplier;
  }

  // Get real letter spacing based on slider value
  double getRealLetterSpacing() {
    // Map slider value (0.0-1.0) to letter spacing (0.0-3.0)
    return _letterSpacing * 3.0;
  }

  // Get real reading speed factor based on slider value
  double getReadingSpeedFactor() {
    // Map slider value (0.0-1.0) to speed factor (0.5-2.0)
    // Where 0.5 is half speed, 1.0 is normal speed, 2.0 is double speed
    return 0.5 + (_readingSpeed * 1.5);
  }
}
