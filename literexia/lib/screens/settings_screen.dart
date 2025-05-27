// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/settings/font/font_selection_dialog.dart';
import 'package:provider/provider.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart'; // Updated import path
import 'package:just_audio/just_audio.dart';

class TTSTestingSection extends StatelessWidget {
  final ThemeProvider themeProvider;
  final AppThemeData theme;
  final TTSProvider ttsProvider;

  const TTSTestingSection({
    Key? key,
    required this.themeProvider,
    required this.theme,
    required this.ttsProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Test Text-to-Speech',
          style: TextStyle(
            color: theme.textColor,
            fontSize: themeProvider.getRealFontSize(16),
            fontWeight: FontWeight.w500,
            fontFamily: themeProvider.fontFamily,
            letterSpacing: themeProvider.getRealLetterSpacing(),
          ),
        ),
        const SizedBox(height: 8),

        // TTS Status indicator
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ttsProvider.isAvailable
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                ttsProvider.isAvailable ? Icons.check_circle : Icons.error,
                color: ttsProvider.isAvailable ? Colors.green : Colors.red,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  ttsProvider.isAvailable
                      ? "PlayAI TTS Service Available"
                      : "PlayAI TTS Service Not Available - Check Internet Connection",
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: themeProvider.getRealFontSize(14),
                    fontFamily: themeProvider.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Additional status info if not connected
        if (!ttsProvider.isAvailable) ...[
          const SizedBox(height: 8),
          Text(
            "Status: ${ttsProvider.connectionStatus}",
            style: TextStyle(
              color: theme.textColor.withOpacity(0.8),
              fontSize: themeProvider.getRealFontSize(12),
              fontFamily: themeProvider.fontFamily,
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Action buttons
        Row(
          children: [
            // Test button
            Expanded(
              child: ElevatedButton(
                onPressed: ttsProvider.isAvailable && ttsProvider.isEnabled
                    ? () async {
                        await ttsProvider.testTTS();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: theme.buttonTextColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  ttsProvider.isPlaying ? 'Playing...' : 'Test PlayAI TTS',
                  style: TextStyle(
                    fontSize: themeProvider.getRealFontSize(14),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                    letterSpacing: themeProvider.getRealLetterSpacing(),
                  ),
                ),
              ),
            ),

            SizedBox(width: 8),

            // Refresh connection button
            ElevatedButton(
              onPressed: () async {
                // Refresh connection
                await ttsProvider.refreshConnection();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showThemeTab = true;
  bool _showAccessibilityTab = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  void _playButtonAudio() async {
    try {
      await _audioPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _audioPlayer.play();
    } catch (e) {
      // Handle audio error silently
    }
  }

  void _showFontSelectionDialog(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FontSelectionDialog(
          currentFont: themeProvider.fontFamily,
          availableFonts: themeProvider.availableFonts,
          onFontSelected: (String selectedFont) {
            _playButtonAudio();
            themeProvider.setFontFamily(selectedFont);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, TTSProvider>(
      builder: (context, themeProvider, ttsProvider, _) {
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
                          _playButtonAudio();
                          setState(() {
                            _showThemeTab = true;
                            _showAccessibilityTab = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _showThemeTab
                              ? theme.accentColor
                              : theme.primaryColor,
                          foregroundColor: _showThemeTab
                              ? theme.buttonTextColor
                              : theme.textColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: _showThemeTab
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
                          _playButtonAudio();
                          setState(() {
                            _showThemeTab = false;
                            _showAccessibilityTab = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _showAccessibilityTab
                              ? theme.accentColor
                              : theme.primaryColor,
                          foregroundColor: _showAccessibilityTab
                              ? theme.buttonTextColor
                              : theme.textColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: _showAccessibilityTab
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
                                value: ttsProvider.isEnabled &&
                                    ttsProvider.isAvailable,
                                onChanged: ttsProvider.isAvailable
                                    ? (value) {
                                        _playButtonAudio();
                                        ttsProvider.setEnabled(value);
                                      }
                                    : null,
                                activeColor: theme.accentColor,
                                activeTrackColor: theme.accentColor.withOpacity(
                                  0.5,
                                ),
                              ),
                            ],
                          ),

                          // Add TTS Testing Section here
                          if (ttsProvider.isEnabled)
                            TTSTestingSection(
                              themeProvider: themeProvider,
                              theme: theme,
                              ttsProvider: ttsProvider,
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

                          GestureDetector(
                            onTap: () {
                              _playButtonAudio();
                              _showFontSelectionDialog(themeProvider);
                            },
                            child: Container(
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    themeProvider.fontFamily,
                                    style: TextStyle(
                                      color: theme.buttonTextColor,
                                      fontSize:
                                          themeProvider.getRealFontSize(16),
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
                        final isSelected = theme.name ==
                            ThemeProvider.availableThemes[index].name;

                        return GestureDetector(
                          onTap: () {
                            _playButtonAudio();
                            themeProvider.setThemeByIndex(index);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: ThemeProvider
                                  .availableThemes[index].accentColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: isSelected
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
                      _playButtonAudio();

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

                  // Bottom spacing
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
