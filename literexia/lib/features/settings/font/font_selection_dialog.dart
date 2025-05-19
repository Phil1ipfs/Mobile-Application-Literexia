// lib/features/settings/ui/font_selection_dialog.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

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
    return Dialog(
      backgroundColor: AppTheme.primaryDarkBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.amber, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Font',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableFonts.length,
                itemBuilder: (context, index) {
                  final font = availableFonts[index];
                  final isSelected = font == selectedFont;
                  
                  return ListTile(
                    title: Text(
                      font,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: font,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected 
                        ? const Icon(Icons.check, color: Colors.amber)
                        : null,
                    onTap: () {
                      onFontSelected(font);
                      Navigator.of(context).pop();
                    },
                    tileColor: isSelected ? Colors.amber.withOpacity(0.2) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}