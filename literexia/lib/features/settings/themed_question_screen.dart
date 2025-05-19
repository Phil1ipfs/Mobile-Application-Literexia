// lib/features/settings/ui/themed_question_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:provider/provider.dart';

class ThemedQuestionScreen extends StatelessWidget {
  final String question;
  final List<String> options;
  final int questionIndex;
  final int totalQuestions;
  final Function(int) onOptionSelected;
  final VoidCallback? onContinue;
  final String? continueButtonText;
  final bool isLastQuestion;

  const ThemedQuestionScreen({
    Key? key,
    required this.question,
    required this.options,
    required this.questionIndex,
    required this.totalQuestions,
    required this.onOptionSelected,
    this.onContinue,
    this.continueButtonText,
    this.isLastQuestion = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = themeProvider.currentTheme;

        return Scaffold(
          backgroundColor: theme.primaryColor,
          body: SafeArea(
            child: Column(
              children: [
                // Top progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: theme.textColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: theme.accentColor,
                              width: 2,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Progress bar fill
                              FractionallySizedBox(
                                widthFactor: questionIndex / totalQuestions,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.accentColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              // Progress text
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: Text(
                                    '$questionIndex/$totalQuestions',
                                    style: TextStyle(
                                      color: theme.textColor,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: themeProvider.fontFamily,
                                      letterSpacing:
                                          themeProvider.getRealLetterSpacing(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Question image or placeholder
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.accentColor,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.image,
                                  size: 80,
                                  color: theme.accentColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Question text
                          Text(
                            question,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: themeProvider.getRealFontSize(24),
                              fontWeight: FontWeight.bold,
                              letterSpacing:
                                  themeProvider.getRealLetterSpacing(),
                              fontFamily: themeProvider.fontFamily,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),

                          // Option buttons
                          ...List.generate(options.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: ElevatedButton(
                                onPressed: () => onOptionSelected(index),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: theme.textColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(
                                      color: theme.accentColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  options[index],
                                  style: TextStyle(
                                    fontSize: themeProvider.getRealFontSize(18),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing:
                                        themeProvider.getRealLetterSpacing(),
                                    fontFamily: themeProvider.fontFamily,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),

                // Continue button
                if (onContinue != null)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ElevatedButton(
                      onPressed: onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: theme.buttonTextColor,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        continueButtonText ??
                            (isLastQuestion ? 'MAG PATULOY' : 'SUSUNOD'),
                        style: TextStyle(
                          fontSize: themeProvider.getRealFontSize(18),
                          fontWeight: FontWeight.bold,
                          letterSpacing: themeProvider.getRealLetterSpacing(),
                          fontFamily: themeProvider.fontFamily,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
