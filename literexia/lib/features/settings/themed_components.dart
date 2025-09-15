import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:provider/provider.dart';

/// Widget to display a themed assessment or lesson card
class ThemedLessonCard extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final int questionCount;
  final bool isAvailable;
  final Function(int) onStartLesson;

  const ThemedLessonCard({
    Key? key,
    required this.index,
    required this.title,
    required this.description,
    required this.questionCount,
    required this.isAvailable,
    required this.onStartLesson,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.7,
      child: Card(
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.3),
        color: theme.primaryColor.withOpacity(0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.accentColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.quiz,
                        color: theme.buttonTextColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: themeProvider.getRealFontSize(16),
                          fontWeight: FontWeight.bold,
                          fontFamily: themeProvider.fontFamily,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Description text
                Text(
                  description,
                  style: TextStyle(
                    color: theme.textColor.withOpacity(0.8),
                    fontSize: themeProvider.getRealFontSize(14),
                    fontFamily: themeProvider.fontFamily,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 16),

                // Question count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.textColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    '$questionCount Questions • Filipino',
                    style: TextStyle(
                      color: theme.textColor.withOpacity(0.7),
                      fontSize: themeProvider.getRealFontSize(12),
                      fontFamily: themeProvider.fontFamily,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Button at bottom
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isAvailable ? () => onStartLesson(index) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: theme.buttonTextColor,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      disabledBackgroundColor:
                          theme.accentColor.withOpacity(0.3),
                    ),
                    child: Text(
                      'SIMULAN ANG PAGTATASA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: themeProvider.getRealFontSize(14),
                        fontFamily: themeProvider.fontFamily,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget for themed empty lessons message
class ThemedEmptyLessonsMessage extends StatelessWidget {
  const ThemedEmptyLessonsMessage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 60, color: theme.accentColor),
            const SizedBox(height: 16),
            Text(
              'No lessons found',
              style: TextStyle(
                color: theme.textColor,
                fontSize: themeProvider.getRealFontSize(20),
                fontWeight: FontWeight.bold,
                fontFamily: themeProvider.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your teacher has not added any lessons yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor.withOpacity(0.7),
                fontSize: themeProvider.getRealFontSize(16),
                fontFamily: themeProvider.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for themed navigation bar item
class ThemedNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const ThemedNavItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected
                ? theme.accentColor
                : theme.textColor.withOpacity(0.7),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? theme.accentColor
                  : theme.textColor.withOpacity(0.7),
              fontSize: themeProvider.getRealFontSize(12),
              fontFamily: themeProvider.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
