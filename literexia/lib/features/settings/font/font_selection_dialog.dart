// lib/features/settings/font/font_selection_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/theme_provider.dart';

class FontSelectionDialog extends StatefulWidget {
  final String currentFont;
  final List<String> availableFonts;
  final Function(String) onFontSelected;

  const FontSelectionDialog({
    Key? key,
    required this.currentFont,
    required this.availableFonts,
    required this.onFontSelected,
  }) : super(key: key);

  @override
  State<FontSelectionDialog> createState() => _FontSelectionDialogState();
}

class _FontSelectionDialogState extends State<FontSelectionDialog> {
  late String _selectedFont;

  @override
  void initState() {
    super.initState();
    _selectedFont = widget.currentFont;
  }

  // Helper method to get font-specific descriptions
  String _getFontDescription(String fontName) {
    switch (fontName) {
      case 'Century Gothic':
        return 'Modern, clean, easy to read';
      case 'Open Dyslexic':
        return 'Designed for dyslexia accessibility';
      case 'BubblegumSans':
        return 'Fun, playful, kid-friendly';
      case 'Roboto':
        return 'Clean, modern, technical';
      case 'OpenSans':
        return 'Neutral, readable, versatile';
      case 'Montserrat':
        return 'Elegant, professional';
      case 'Poppins':
        return 'Rounded, friendly, modern';
      default:
        return 'Custom font option';
    }
  }

  // Helper method to get appropriate sample text for each font
  String _getSampleText(String fontName) {
    switch (fontName) {
      case 'Open Dyslexic':
        return 'Madaling basahin para sa lahat';
      case 'Century Gothic':
        return 'Magandang Araw - Default Font';
      case 'BubblegumSans':
        return 'Masayang Pagbasa!';
      default:
        return 'Magandang Araw - Sample Text';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = themeProvider.currentTheme;

        return Dialog(
          backgroundColor: theme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: theme.name == 'Blue' ? Colors.white : theme.accentColor, 
              width: 2
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Font',
                      style: TextStyle(
                        color: theme.name == 'Blue' ? Colors.white : theme.textColor,
                        fontSize: themeProvider.getRealFontSize(20),
                        fontWeight: FontWeight.bold,
                        fontFamily: themeProvider.fontFamily,
                        letterSpacing: themeProvider.getRealLetterSpacing(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.name == 'Blue' ? Colors.white : theme.textColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Font preview text with current selection
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.name == 'Blue' 
                          ? Colors.white.withOpacity(0.3) 
                          : theme.accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Font Preview',
                        style: TextStyle(
                          color: theme.name == 'Blue' ? Colors.white : theme.textColor,
                          fontSize: themeProvider.getRealFontSize(18),
                          fontWeight: FontWeight.bold,
                          fontFamily: _selectedFont,
                          letterSpacing: themeProvider.getRealLetterSpacing(),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getSampleText(_selectedFont),
                        style: TextStyle(
                          color: theme.name == 'Blue' 
                              ? Colors.white.withOpacity(0.8)
                              : theme.textColor.withOpacity(0.8),
                          fontSize: themeProvider.getRealFontSize(14),
                          fontFamily: _selectedFont,
                          letterSpacing: themeProvider.getRealLetterSpacing(),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getFontDescription(_selectedFont),
                        style: TextStyle(
                          color: theme.name == 'Blue' 
                              ? Colors.white.withOpacity(0.6)
                              : theme.textColor.withOpacity(0.6),
                          fontSize: themeProvider.getRealFontSize(12),
                          fontFamily: _selectedFont,
                          letterSpacing: themeProvider.getRealLetterSpacing(),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Font list
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: widget.availableFonts.map((font) {
                        final isSelected = font == _selectedFont;
                        final isDefault = font == 'Century Gothic';
                        final isAccessibility = font == 'Open Dyslexic';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  _selectedFont = font;
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (theme.name == 'Blue' 
                                          ? Colors.white.withOpacity(0.2)
                                          : theme.accentColor.withOpacity(0.2))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? (theme.name == 'Blue' ? Colors.white : theme.accentColor)
                                        : (theme.name == 'Blue' 
                                            ? Colors.white.withOpacity(0.2)
                                            : theme.textColor.withOpacity(0.2)),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Font name and sample
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Font name with badges
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  font,
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? (theme.name == 'Blue' ? Colors.white : theme.accentColor)
                                                        : (theme.name == 'Blue' ? Colors.white : theme.textColor),
                                                    fontSize: themeProvider
                                                        .getRealFontSize(16),
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                    fontFamily: font,
                                                    letterSpacing: themeProvider
                                                        .getRealLetterSpacing(),
                                                  ),
                                                ),
                                              ),

                                              // Default badge
                                              if (isDefault)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      left: 8),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade400,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    'DEFAULT',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: themeProvider
                                                          .getRealFontSize(10),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),

                                              // Accessibility badge
                                              if (isAccessibility)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      left: 8),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.green.shade400,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    'ACCESSIBLE',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: themeProvider
                                                          .getRealFontSize(10),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),

                                          const SizedBox(height: 4),

                                          // Sample text
                                          Text(
                                            _getSampleText(font),
                                            style: TextStyle(
                                              color: theme.name == 'Blue'
                                                  ? Colors.white.withOpacity(0.7)
                                                  : theme.textColor.withOpacity(0.7),
                                              fontSize: themeProvider
                                                  .getRealFontSize(12),
                                              fontFamily: font,
                                              letterSpacing: themeProvider
                                                  .getRealLetterSpacing(),
                                            ),
                                          ),

                                          // Description
                                          Text(
                                            _getFontDescription(font),
                                            style: TextStyle(
                                              color: theme.name == 'Blue'
                                                  ? Colors.white.withOpacity(0.5)
                                                  : theme.textColor.withOpacity(0.5),
                                              fontSize: themeProvider
                                                  .getRealFontSize(10),
                                              fontFamily:
                                                  themeProvider.fontFamily,
                                              letterSpacing: themeProvider
                                                  .getRealLetterSpacing(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Selection indicator
                                    if (isSelected)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: theme.name == 'Blue' ? Colors.white : theme.accentColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check,
                                          color: theme.name == 'Blue' ? Colors.blue : theme.buttonTextColor,
                                          size: 16,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.name == 'Blue' ? Colors.white : theme.textColor,
                          side: BorderSide(
                            color: theme.name == 'Blue' ? Colors.white : theme.accentColor,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: themeProvider.getRealFontSize(16),
                            fontWeight: FontWeight.bold,
                            fontFamily: themeProvider.fontFamily,
                            letterSpacing: themeProvider.getRealLetterSpacing(),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Apply button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onFontSelected(_selectedFont);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.name == 'Blue' ? Colors.white : theme.accentColor,
                          foregroundColor: theme.name == 'Blue' ? Colors.blue : theme.buttonTextColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: themeProvider.getRealFontSize(16),
                            fontWeight: FontWeight.bold,
                            fontFamily: themeProvider.fontFamily,
                            letterSpacing: themeProvider.getRealLetterSpacing(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
