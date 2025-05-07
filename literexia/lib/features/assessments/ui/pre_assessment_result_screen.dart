// lib/features/assessments/ui/pre_assessment_result_screen.dart
import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../../../config/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/logic/auth_provider.dart';

class PreAssessmentResultScreen extends StatefulWidget {
  final String readingLevel;
  final int score;
  final int totalQuestions;
  final double? readingPercentage;

  const PreAssessmentResultScreen({
    Key? key,
    required this.readingLevel,
    required this.score,
    required this.totalQuestions,
    this.readingPercentage,
  }) : super(key: key);

  @override
  State<PreAssessmentResultScreen> createState() => _PreAssessmentResultScreenState();
}

class _PreAssessmentResultScreenState extends State<PreAssessmentResultScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    
    // Start confetti animation after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _confettiController.play();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String _getLevelDescription(String level) {
    switch (level.toLowerCase()) {
      case "low emerging":
        return "Learner with the scores 0 to 16 upon the administration of Part 1: Task 1 and 2.";
      case "high emerging":
        return "Learner with the scores 17 to 30 upon the administration of Part 1 and reads less than 25% and cannot answer any of the questions.";
      case "developing":
        return "Learner with the scores 17 to 30 upon the administration of Part 1 and reads between 26-50% and answers at least 1 question correctly.";
      case "transitioning":
        return "Learner with the scores 17 to 30 upon the administration of Part 1 and reads between 51-75% and answers at least 2-3 questions correctly.";
      case "at grade level":
        return "Learner with the scores 17 to 30 upon the administration of Part 1 and reads between 76-100% and answers at least 4 to 5 questions correctly.";
      case "emergent":
        return "You're just beginning your reading journey. We'll focus on letter recognition and basic sounds.";
      case "early":
        return "You're building good reading skills. We'll work on word formation and simple reading.";
      case "fluent":
        return "Great job! You have strong reading skills. We'll challenge you with more complex reading tasks.";
      default:
        return "Assessment completed! Continue your learning journey.";
    }
  }

  int _getLevelStage(String level) {
    switch (level.toLowerCase()) {
      case "low emerging":
        return 1;
      case "high emerging":
        return 2;
      case "developing":
        return 3;
      case "transitioning":
        return 4;
      case "at grade level":
        return 5;
      case "emergent":
        return 1;
      case "early":
        return 2;
      case "fluent":
        return 3;
      default:
        return 0;
    }
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case "low emerging":
      case "emergent":
        return Colors.red.shade300;
      case "high emerging":
      case "early":
        return Colors.orange.shade300;
      case "developing":
        return Colors.yellow.shade300;
      case "transitioning":
        return Colors.blue.shade300;
      case "at grade level":
      case "fluent":
        return Colors.green.shade300;
      default:
        return Colors.amber;
    }
  }

  String _getLevelEmoji(String level) {
    switch (level.toLowerCase()) {
      case "low emerging":
      case "emergent":
        return '🌱';
      case "high emerging":
      case "early":
        return '🌿';
      case "developing":
        return '🌻';
      case "transitioning":
        return '🌲';
      case "at grade level":
      case "fluent":
        return '🌳';
      default:
        return '📚';
    }
  }
  
  // New method to navigate based on reading level
  void _navigateBasedOnLevel(BuildContext context, String readingLevel) {
    // Update the AuthProvider with this reading level to ensure it's available throughout the app
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      authProvider.updateUserReadingLevel(readingLevel);
    }
    
    // Navigate to the appropriate screen based on reading level
    Navigator.of(context).pushReplacementNamed(AppRouter.home, arguments: {
      'readingLevel': readingLevel
    });
  }

  @override
  Widget build(BuildContext context) {
    final readingPercentage = widget.readingPercentage?.toStringAsFixed(1) ?? '0.0';
    final levelStage = _getLevelStage(widget.readingLevel);
    final levelColor = _getLevelColor(widget.readingLevel);

    return Scaffold(
      backgroundColor: AppTheme.primaryDarkBlue,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40), // Space for confetti
                  
                  // Reading level icon
                  // Reading level icon
                  Text(
                    _getLevelEmoji(widget.readingLevel),
                    style: const TextStyle(fontSize: 70),
                  ),
                  const SizedBox(height: 20),
                  
                  // Assessment complete text
                  const Text(
                    'Assessment Complete!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  // Reading level result
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: levelColor,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Stage $levelStage: ',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.readingLevel,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Score & Reading Percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Score display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Score: ${widget.score}/${widget.totalQuestions}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Reading percentage display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Reading: $readingPercentage%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  // Level description
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: levelColor.withOpacity(0.7)),
                    ),
                    child: Text(
                      _getLevelDescription(widget.readingLevel),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Modified Continue to home button
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        // Navigate based on reading level
                        _navigateBasedOnLevel(context, widget.readingLevel);
                      },
                      child: const Text(
                        'Continue to Home',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: Math.pi / 2, // Straight down
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: [
                levelColor, 
                Colors.amber,
                Colors.blue,
                Colors.pink,
                Colors.green,
              ],
            ),
          ),
        ],
      ),
    );
  }
}