import 'package:flutter/material.dart';

class AppTheme {
  // Main colors
  static const Color primaryDarkBlue = Color(0xFF2E3A5C);
  static const Color primaryLightBlue = Color(0xFF5D6A98);
  static const Color accentAmber = Colors.amber;
  static const Color lessonPanelBlue = Color(0xFF3F5497);
  static const Color expandedLessonBlue = Color(0xFF2E78C8);

  // Text styles
  static const TextStyle titleTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  static const TextStyle subtitleTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle bodyTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle navTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
  );

  // Theme configuration
  static final ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: primaryLightBlue,
    primaryColor: primaryDarkBlue,
    colorScheme: const ColorScheme.light(
      primary: primaryDarkBlue,
      secondary: accentAmber,
      background: primaryLightBlue,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryDarkBlue,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentAmber,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: titleTextStyle,
      displayMedium: subtitleTextStyle,
      bodyLarge: bodyTextStyle,
      bodyMedium: navTextStyle,
    ),
  );
}
