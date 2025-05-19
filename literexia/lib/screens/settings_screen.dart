// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showColorThemes = true;
  bool _showAccessibilitySettings = false;
  bool _showPetTheme = false;

  final List<ThemeColor> _themeColors = [
    ThemeColor(name: 'White', color: Colors.white, textColor: Colors.black),
    ThemeColor(name: 'Red', color: Colors.red, textColor: Colors.white),
    ThemeColor(name: 'Orange', color: Colors.orange, textColor: Colors.white),
    ThemeColor(name: 'Black', color: Colors.black, textColor: Colors.white),
    ThemeColor(name: 'Blue', color: const Color(0xFF334970), textColor: Colors.white),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Scaffold(
          backgroundColor: settingsProvider.isDarkMode 
              ? AppTheme.primaryDarkBlue 
              : settingsProvider.themeColor.color,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.close,
                color: settingsProvider.themeColor.textColor,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            title: Text(
              'SETTINGS',
              style: TextStyle(
                color: settingsProvider.themeColor.textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Customize your Theme',
                    style: TextStyle(
                      color: settingsProvider.themeColor.textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  
                  // Theme Selection Tabs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTabButton(
                        'Colors', 
                        _showColorThemes, 
                        () => _switchTab(0),
                        settingsProvider,
                      ),
                      const SizedBox(width: 10),
                      _buildTabButton(
                        'Accessibility', 
                        _showAccessibilitySettings, 
                        () => _switchTab(1),
                        settingsProvider,
                      ),
                      const SizedBox(width: 10),
                      _buildTabButton(
                        'Themes', 
                        _showPetTheme, 
                        () => _switchTab(2),
                        settingsProvider,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Color Themes View
                  if (_showColorThemes) _buildColorThemesView(settingsProvider),
                  
                  // Accessibility Settings View
                  if (_showAccessibilitySettings) _buildAccessibilityView(settingsProvider),
                  
                  // Pet Theme View
                  if (_showPetTheme) _buildPetThemeView(settingsProvider),
                  
                  const SizedBox(height: 30),
                  
                  // Color Selection Circles
                  Text(
                    'Mga Kulay',
                    style: TextStyle(
                      color: settingsProvider.themeColor.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Color Selection Circles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _themeColors.map((themeColor) {
                      return GestureDetector(
                        onTap: () {
                          settingsProvider.setThemeColor(themeColor);
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: themeColor.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: settingsProvider.themeColor == themeColor
                                  ? Colors.amber
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Save Button
                  ElevatedButton(
                    onPressed: () {
                      settingsProvider.saveSettings();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settings saved'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.save),
                        SizedBox(width: 10),
                        Text(
                          'Save Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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

  Widget _buildTabButton(String title, bool isSelected, VoidCallback onTap, SettingsProvider settingsProvider) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.amber : Colors.grey.withOpacity(0.3),
        foregroundColor: isSelected ? Colors.black : settingsProvider.themeColor.textColor,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildColorThemesView(SettingsProvider settingsProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: settingsProvider.isDarkMode
            ? AppTheme.lessonPanelBlue
            : settingsProvider.themeColor.color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'SALITA',
            style: TextStyle(
              color: settingsProvider.themeColor.textColor,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tanong',
            style: TextStyle(
              color: settingsProvider.themeColor.textColor,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Sagot A',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Sagot B',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityView(SettingsProvider settingsProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: settingsProvider.isDarkMode
            ? AppTheme.lessonPanelBlue
            : settingsProvider.themeColor.color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text-to-Speech
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Text-to-Speech',
                style: TextStyle(
                  color: settingsProvider.themeColor.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Switch(
                value: settingsProvider.textToSpeechEnabled,
                onChanged: (value) {
                  settingsProvider.setTextToSpeechEnabled(value);
                },
                activeColor: Colors.amber,
                activeTrackColor: Colors.amber.withOpacity(0.5),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // Font Selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Font',
                style: TextStyle(
                  color: settingsProvider.themeColor.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      settingsProvider.fontFamily,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // Reading Speed
          Text(
            'Reading Speed',
            style: TextStyle(
              color: settingsProvider.themeColor.textColor,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Slow',
                style: TextStyle(
                  color: settingsProvider.themeColor.textColor,
                ),
              ),
              Expanded(
                child: Slider(
                  value: settingsProvider.readingSpeed,
                  onChanged: (value) {
                    settingsProvider.setReadingSpeed(value);
                  },
                  min: 0.0,
                  max: 1.0,
                  activeColor: Colors.amber,
                  inactiveColor: Colors.grey,
                ),
              ),
              Text(
                'Fast',
                style: TextStyle(
                  color: settingsProvider.themeColor.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // Text Size
          Text(
            'Text Size',
            style: TextStyle(
              color: settingsProvider.themeColor.textColor,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'A',
                style: TextStyle(
                  color: settingsProvider.themeColor.textColor,
                  fontSize: 16,
                ),
              ),
              Expanded(
                child: Slider(
                  value: settingsProvider.textSize,
                  onChanged: (value) {
                    settingsProvider.setTextSize(value);
                  },
                  min: 0.0,
                  max: 1.0,
                  activeColor: Colors.amber,
                  inactiveColor: Colors.grey,
                ),
              ),
              Text(
                'A',
                style: TextStyle(
                  color: settingsProvider.themeColor.textColor,
                  fontSize: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // Letter Spacing
          Text(
            'Letter Spacing',
            style: TextStyle(
              color: settingsProvider.themeColor.textColor,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Normal',
                style: TextStyle(
                  color: settingsProvider.themeColor.textColor,
                ),
              ),
              Expanded(
                child: Slider(
                  value: settingsProvider.letterSpacing,
                  onChanged: (value) {
                    settingsProvider.setLetterSpacing(value);
                  },
                  min: 0.0,
                  max: 1.0,
                  activeColor: Colors.amber,
                  inactiveColor: Colors.grey,
                ),
              ),
              Text(
                'Wide',
                style: TextStyle(
                  color: settingsProvider.themeColor.textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPetThemeView(SettingsProvider settingsProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: settingsProvider.isDarkMode
            ? AppTheme.lessonPanelBlue
            : settingsProvider.themeColor.color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/dog.png',
                    width: 60,
                    height: 60,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.pets,
                        size: 60,
                        color: Colors.amber,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amber, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'ASO',
                  style: TextStyle(
                    color: settingsProvider.themeColor.textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // Divider
          Container(
            height: 1,
            color: Colors.amber.withOpacity(0.5),
          ),
          const SizedBox(height: 30),
          
          // ASO button small
          Container(
            width: 150,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text(
                'ASO',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          // Divider
          Container(
            height: 1,
            color: Colors.amber.withOpacity(0.5),
          ),
          const SizedBox(height: 30),
          
          // ASO and PUSA buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 150,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Text(
                    'ASO',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Container(
                width: 150,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: Center(
                  child: Text(
                    'PUSA',
                    style: TextStyle(
                      color: settingsProvider.themeColor.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // KABAYO and DAGA buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 150,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: Center(
                  child: Text(
                    'KABAYO',
                    style: TextStyle(
                      color: settingsProvider.themeColor.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Container(
                width: 150,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: Center(
                  child: Text(
                    'DAGA',
                    style: TextStyle(
                      color: settingsProvider.themeColor.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _switchTab(int tabIndex) {
    setState(() {
      _showColorThemes = tabIndex == 0;
      _showAccessibilitySettings = tabIndex == 1;
      _showPetTheme = tabIndex == 2;
    });
  }
}