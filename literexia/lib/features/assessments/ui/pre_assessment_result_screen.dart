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
  State<PreAssessmentResultScreen> createState() =>
      _PreAssessmentResultScreenState();
}

class _PreAssessmentResultScreenState extends State<PreAssessmentResultScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  
  // Multiple animation controllers for different effects
  late AnimationController _floatController;
  late AnimationController _rotateController;
  late AnimationController _twinkleController;
  
  // Animations
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _twinkleAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );

    // Setup floating animation (up and down)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ),
    );

    // Setup rotation animation
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _rotateAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _rotateController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Setup twinkling animation
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _twinkleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _twinkleController,
        curve: Curves.easeInOut,
      ),
    );

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
    _floatController.dispose();
    _rotateController.dispose();
    _twinkleController.dispose();
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

  Widget _getLevelStars(String level) {
    int starCount;
    
    switch (level.toLowerCase()) {
      case "low emerging":
      case "emergent":
        starCount = 1;
        break;
      case "high emerging":
      case "early":
        starCount = 2;
        break;
      case "developing":
        starCount = 3;
        break;
      case "transitioning":
        starCount = 4;
        break;
      case "at grade level":
      case "fluent":
        starCount = 5;
        break;
      default:
        starCount = 1;
    }
    
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _rotateController, _twinkleController]),
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            starCount,
            (index) {
              // Calculate a phase offset based on index for wave-like effect
              final phaseOffset = index * 0.4;
              
              // Create a custom floating animation for each star
              final individualFloat = _floatAnimation.value * 
                Math.sin(((_floatController.value * Math.pi * 2) + phaseOffset) % (Math.pi * 2));
              
              return Transform.translate(
                offset: Offset(0, individualFloat),
                child: Transform.rotate(
                  angle: _rotateAnimation.value * (index % 2 == 0 ? 1 : -1), // Alternate rotation direction
                  child: Opacity(
                    opacity: _twinkleAnimation.value - (index * 0.05 * _twinkleAnimation.value % 0.3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Container(
                        width: 50,
                        height: 50,
                        child: Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Kid-friendly descriptions that don't mention the level names
  String _getKidFriendlyDescription(String level) {
    switch (level.toLowerCase()) {
      case "low emerging":
      case "emergent":
        return "You're doing great! Let's continue learning letters and sounds together.";
      case "high emerging":
      case "early":
        return "Awesome job! You're building your reading skills. Let's learn more words together!";
      case "developing":
        return "Amazing work! You're growing as a reader. Keep practicing and having fun!";
      case "transitioning":
        return "Excellent! Your reading is getting stronger every day. Let's continue our adventure!";
      case "at grade level":
      case "fluent":
        return "Incredible! You're becoming a fantastic reader. Let's explore more exciting stories!";
      default:
        return "You did a great job! Let's continue our learning adventure together.";
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

  // Build score summary that includes reading percentage
  Widget _buildScoreSummary() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            'Score: ${widget.score}/${widget.totalQuestions}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          if (widget.readingPercentage != null)
            Text(
              'Reading: ${widget.readingPercentage!.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }

  // New method to navigate based on reading level
  void _navigateBasedOnLevel(BuildContext context, String readingLevel) {
    // Update the AuthProvider with this reading level to ensure it's available throughout the app
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      authProvider.updateUserReadingLevel(readingLevel);
      if (widget.readingPercentage != null) {
        authProvider.updateReadingPercentage(widget.readingPercentage!);
      }
    }

    // Navigate to the appropriate screen based on reading level
    Navigator.of(context).pushReplacementNamed(
      AppRouter.home,
      arguments: {'readingLevel': readingLevel},
    );
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _getLevelColor(widget.readingLevel);
    // Calculate the level stage but don't display it in the UI
    final levelStage = _getLevelStage(widget.readingLevel);
    
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
                  
                  // Animated stars based on level
                  _getLevelStars(widget.readingLevel),
                  const SizedBox(height: 20),

                  // Assessment complete text with congratulations
                  const Text(
                    'Assessment Complete!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  
                  const Text(
                    'Great job!',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  // Score summary
                  _buildScoreSummary(),
                  const SizedBox(height: 20),

                  // Level description - kid-friendly version without level names
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: levelColor.withOpacity(0.7)),
                    ),
                    child: Text(
                      _getKidFriendlyDescription(widget.readingLevel),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Continue to home button
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