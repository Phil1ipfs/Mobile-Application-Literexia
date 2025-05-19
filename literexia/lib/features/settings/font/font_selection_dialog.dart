// lib/features/settings/ui/font_selection_dialog.dart
import 'package:flutter/material.dart';
import '../provider/theme_provider.dart';
import 'package:provider/provider.dart';

class FontSelectionDialog extends StatelessWidget {
  final List<String> availableFonts;
  final String selectedFont;
  final Function(String) onFontSelected;

  const FontSelectionDialog({
    Key? key,
    required this.availableFonts,
    required this.selectedFont,
    required this.onFontSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return Dialog(
      backgroundColor: theme.primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.accentColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Font',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: themeProvider.getRealLetterSpacing(),
                fontFamily: themeProvider.fontFamily,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableFonts.length,
                itemBuilder: (context, index) {
                  final font = availableFonts[index];
                  final isSelected = font == selectedFont;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? theme.accentColor.withOpacity(0.2)
                              : null,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          isSelected
                              ? Border.all(color: theme.accentColor)
                              : null,
                    ),
                    child: ListTile(
                      title: Text(
                        font,
                        style: TextStyle(
                          color: theme.textColor,
                          fontFamily: font,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                          letterSpacing: themeProvider.getRealLetterSpacing(),
                        ),
                      ),
                      subtitle: Text(
                        'Sample Text in $font',
                        style: TextStyle(
                          color: theme.textColor.withOpacity(0.7),
                          fontFamily: font,
                          fontSize: 14,
                          letterSpacing: themeProvider.getRealLetterSpacing(),
                        ),
                      ),
                      trailing:
                          isSelected
                              ? Icon(Icons.check, color: theme.accentColor)
                              : null,
                      onTap: () {
                        onFontSelected(font);
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: theme.accentColor,
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                      fontFamily: themeProvider.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
