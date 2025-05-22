// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/settings/font/font_selection_dialog.dart';
import 'package:provider/provider.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:just_audio/just_audio.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showThemeTab = true;
  bool _showAccessibilityTab = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = themeProvider.currentTheme;

        return Scaffold(
          backgroundColor: theme.primaryColor,
          appBar: AppBar(
            backgroundColor: theme.headerColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close, color: theme.textColor),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            title: Text(
              'SETTINGS',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: themeProvider.fontFamily,
                letterSpacing: themeProvider.getRealLetterSpacing(),
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Customize your Theme',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Tab buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Theme tab button
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showThemeTab = true;
                            _showAccessibilityTab = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _showThemeTab
                                  ? theme.accentColor
                                  : theme.primaryColor,
                          foregroundColor:
                              _showThemeTab
                                  ? theme.buttonTextColor
                                  : theme.textColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color:
                                  _showThemeTab
                                      ? Colors.transparent
                                      : theme.accentColor,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          'Theme',
                          style: TextStyle(
                            fontFamily: themeProvider.fontFamily,
                            letterSpacing: themeProvider.getRealLetterSpacing(),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Accessibility tab button
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showThemeTab = false;
                            _showAccessibilityTab = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _showAccessibilityTab
                                  ? theme.accentColor
                                  : theme.primaryColor,
                          foregroundColor:
                              _showAccessibilityTab
                                  ? theme.buttonTextColor
                                  : theme.textColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color:
                                  _showAccessibilityTab
                                      ? Colors.transparent
                                      : theme.accentColor,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          'Accessibility',
                          style: TextStyle(
                            fontFamily: themeProvider.fontFamily,
                            letterSpacing: themeProvider.getRealLetterSpacing(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Theme preview panel
                  if (_showThemeTab) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.accentColor, width: 2),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Sample title
                          Text(
                            'SALITA',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: themeProvider.getRealFontSize(30),
                              fontWeight: FontWeight.bold,
                              fontFamily: themeProvider.fontFamily,
                              letterSpacing:
                                  themeProvider.getRealLetterSpacing(),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Sample subtitle
                          Text(
                            'Tanong',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: themeProvider.getRealFontSize(20),
                              fontFamily: themeProvider.fontFamily,
                              letterSpacing:
                                  themeProvider.getRealLetterSpacing(),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Sample buttons
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.accentColor,
                              foregroundColor: theme.buttonTextColor,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: Text(
                              'Sagot A',
                              style: TextStyle(
                                fontSize: themeProvider.getRealFontSize(16),
                                fontWeight: FontWeight.bold,
                                fontFamily: themeProvider.fontFamily,
                                letterSpacing:
                                    themeProvider.getRealLetterSpacing(),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.accentColor,
                              foregroundColor: theme.buttonTextColor,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: Text(
                              'Sagot B',
                              style: TextStyle(
                                fontSize: themeProvider.getRealFontSize(16),
                                fontWeight: FontWeight.bold,
                                fontFamily: themeProvider.fontFamily,
                                letterSpacing:
                                    themeProvider.getRealLetterSpacing(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Accessibility settings
                  if (_showAccessibilityTab) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.accentColor, width: 2),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Text to speech
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Text-to-Speech',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: themeProvider.getRealFontSize(16),
                                  fontWeight: FontWeight.w500,
                                  fontFamily: themeProvider.fontFamily,
                                  letterSpacing:
                                      themeProvider.getRealLetterSpacing(),
                                ),
                              ),

                              Switch(
                                value: themeProvider.textToSpeechEnabled,
                                onChanged: (value) {
                                  themeProvider.setTextToSpeechEnabled(value);
                                },
                                activeColor: theme.accentColor,
                                activeTrackColor: theme.accentColor.withOpacity(
                                  0.5,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Font selector
                          Text(
                            'Font',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: themeProvider.getRealFontSize(16),
                              fontWeight: FontWeight.w500,
                              fontFamily: themeProvider.fontFamily,
                              letterSpacing:
                                  themeProvider.getRealLetterSpacing(),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: theme.accentColor,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  themeProvider.fontFamily,
                                  style: TextStyle(
                                    color: theme.buttonTextColor,
                                    fontSize: themeProvider.getRealFontSize(16),
                                    fontWeight: FontWeight.w500,
                                    fontFamily: themeProvider.fontFamily,
                                    letterSpacing:
                                        themeProvider.getRealLetterSpacing(),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: theme.buttonTextColor,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Text size slider
                          Text(
                            'Text Size',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: themeProvider.getRealFontSize(16),
                              fontWeight: FontWeight.w500,
                              fontFamily: themeProvider.fontFamily,
                              letterSpacing:
                                  themeProvider.getRealLetterSpacing(),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Text(
                                'A',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: 16,
                                  fontFamily: themeProvider.fontFamily,
                                ),
                              ),

                              Expanded(
                                child: Slider(
                                  value: themeProvider.textSize,
                                  onChanged: (value) {
                                    themeProvider.setTextSize(value);
                                  },
                                  activeColor: theme.accentColor,
                                  inactiveColor: theme.accentColor.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),

                              Text(
                                'A',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: 28,
                                  fontFamily: themeProvider.fontFamily,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Letter spacing slider
                          Text(
                            'Letter Spacing',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: themeProvider.getRealFontSize(16),
                              fontWeight: FontWeight.w500,
                              fontFamily: themeProvider.fontFamily,
                              letterSpacing:
                                  themeProvider.getRealLetterSpacing(),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Text(
                                'Normal',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: 14,
                                  fontFamily: themeProvider.fontFamily,
                                ),
                              ),

                              Expanded(
                                child: Slider(
                                  value: themeProvider.letterSpacing,
                                  onChanged: (value) {
                                    themeProvider.setLetterSpacing(value);
                                  },
                                  activeColor: theme.accentColor,
                                  inactiveColor: theme.accentColor.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),

                              Text(
                                'Wide',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: 14,
                                  letterSpacing: 3.0,
                                  fontFamily: themeProvider.fontFamily,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Reading speed slider
                          Text(
                            'Reading Speed',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: themeProvider.getRealFontSize(16),
                              fontWeight: FontWeight.w500,
                              fontFamily: themeProvider.fontFamily,
                              letterSpacing:
                                  themeProvider.getRealLetterSpacing(),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Text(
                                'Slow',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: 14,
                                  fontFamily: themeProvider.fontFamily,
                                ),
                              ),

                              Expanded(
                                child: Slider(
                                  value: themeProvider.readingSpeed,
                                  onChanged: (value) {
                                    themeProvider.setReadingSpeed(value);
                                  },
                                  activeColor: theme.accentColor,
                                  inactiveColor: theme.accentColor.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),

                              Text(
                                'Fast',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: 14,
                                  fontFamily: themeProvider.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Color selection title
                  Text(
                    'Mga Kulay',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: themeProvider.getRealFontSize(18),
                      fontWeight: FontWeight.w500,
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Color selection circles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      ThemeProvider.availableThemes.length,
                      (index) {
                        final isSelected =
                            theme.name ==
                            ThemeProvider.availableThemes[index].name;

                        return GestureDetector(
                          onTap: () {
                            themeProvider.setThemeByIndex(index);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  ThemeProvider
                                      .availableThemes[index]
                                      .accentColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow:
                                  isSelected
                                      ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                      : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Save button
                  ElevatedButton(
                    onPressed: () async {
                      final success = await themeProvider.saveSettings();

                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Settings saved',
                              style: TextStyle(color: theme.buttonTextColor),
                            ),
                            backgroundColor: theme.accentColor,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to save settings'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: theme.buttonTextColor,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, color: theme.buttonTextColor),
                        const SizedBox(width: 8),
                        Text(
                          'Save Settings',
                          style: TextStyle(
                            fontSize: themeProvider.getRealFontSize(16),
                            fontWeight: FontWeight.bold,
                            fontFamily: themeProvider.fontFamily,
                            letterSpacing: themeProvider.getRealLetterSpacing(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
