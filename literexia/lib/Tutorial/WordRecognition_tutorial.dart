import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'dart:async';

import 'package:literexia/features/assessments/ui/AlphabetKnowledgeScreen.dart';

class WordRecognitionTutorial extends StatefulWidget {
  const WordRecognitionTutorial({Key? key}) : super(key: key);

  @override
  State<WordRecognitionTutorial> createState() =>
      _WordRecognitionTutorialState();
}

class _WordRecognitionTutorialState extends State<WordRecognitionTutorial>
    with TickerProviderStateMixin {
  // Typewriter animation
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  String _displayedText = '';
  bool _showButton = false;

  int _currentScreen = 0;
  Timer? _timer;

  // Tutorial screens data
  final List<Map<String, dynamic>> _tutorialScreens = [
    {
      'type': 'instruction',
      'title': 'Basahin ang pangungusap.',
      'text': 'Piliin ang tamang \n salita mula sa hanay.',
    },
    {
      'type': 'sentence_completion',
      'sentence': 'Naglalaro siya ng ___ sa parke.',
      'text': 'Basahin ang pangungusap.',
    },
    {
      'type': 'word_choices',
      'choices': ['BO', 'PAP', 'KUT', 'LA'],
      'text': 'Piliin ang tamang \n salita mula sa hanay.',
    }
  ];

  @override
  void initState() {
    super.initState();

    // Initialize typewriter controller
    _typewriterController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Start typewriter effect for initial screen
    _setupTypewriter();
  }

  void _setupTypewriter() {
    final currentText = _tutorialScreens[_currentScreen]['text'] as String;

    _typewriterAnimation = IntTween(
      begin: 0,
      end: currentText.length,
    ).animate(CurvedAnimation(
      parent: _typewriterController,
      curve: Curves.linear,
    ));

    _typewriterAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _displayedText = currentText.substring(0, _typewriterAnimation.value);
        });
      }
    });

    _typewriterAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _showButton = true;
        });
      }
    });

    // Reset and start typewriter
    _showButton = false;
    _typewriterController.reset();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _typewriterController.forward();
      }
    });
  }

  void _nextScreen() {
    if (_currentScreen < _tutorialScreens.length - 1) {
      setState(() {
        _currentScreen++;
      });
      _setupTypewriter();
    }
  }

  void _finishTutorial() {
    // Create a new AssessmentProvider instance
    final assessmentProvider = AssessmentProvider();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => AlphabetKnowledgeScreen(
                assessmentId:
                    'PRE_ASSESSMENT_001', // Provide required assessmentId parameter
                provider:
                    assessmentProvider, // Provide required provider parameter
                isPreAssessment: true,
              )),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _typewriterController.dispose();
    super.dispose();
  }

  Widget _buildInstructionScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Instruction title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            screen['title'],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF9D56E),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 80),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _displayedText,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
        const Spacer(),
        if (_showButton) _buildContinueButton(),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildSentenceCompletionScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Sentence with blank - show immediately without typewriter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            screen['sentence'],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF9D56E),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 80),
        // Only apply typewriter to the instructional text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _displayedText,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
        const Spacer(),
        if (_showButton) _buildContinueButton(),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildWordChoicesScreen(Map<String, dynamic> screen) {
    List<String> choices = screen['choices'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Word choice buttons in 2x2 grid - show immediately without typewriter
        Column(
          children: [
            // First row with two buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChoiceButton(choices[0]),
                const SizedBox(width: 20),
                _buildChoiceButton(choices[1]),
              ],
            ),
            const SizedBox(height: 20),
            // Second row with two buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChoiceButton(choices[2]),
                const SizedBox(width: 20),
                _buildChoiceButton(choices[3]),
              ],
            ),
          ],
        ),
        const SizedBox(height: 80),
        // Only apply typewriter to the instructional text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _displayedText,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
        const Spacer(),
        if (_showButton) _buildContinueButton(),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildChoiceButton(String text) {
    return Container(
      width: 120,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC00),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(197, 255, 204, 0), // Shadow color
            offset: Offset(0, 5), // Horizontal & vertical offset
            blurRadius: 0, // Softness of the shadow
            spreadRadius: 0, // Size expansion
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      width: 310,
      height: 50,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(197, 255, 204, 0), // Shadow color
            offset: Offset(0, 5), // Horizontal & vertical offset
            blurRadius: 0, // Softness of the shadow
            spreadRadius: 0, // Size expansion
          ),
        ],
        borderRadius: BorderRadius.circular(10),
      ),
      child: ElevatedButton(
        onPressed: _currentScreen == _tutorialScreens.length - 1
            ? _finishTutorial
            : _nextScreen,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFCC00),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0, // Set to 0 to avoid double shadow
          shadowColor: Colors.transparent, // Disable default shadow
        ),
        child: Text(
          'Mag Patuloy',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentScreenData = _tutorialScreens[_currentScreen];

    return Scaffold(
      backgroundColor: const Color(0xFF1C2B4E),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: Duration.zero,
          child: KeyedSubtree(
            key: ValueKey(_currentScreen),
            child: () {
              switch (currentScreenData['type']) {
                case 'instruction':
                  return _buildInstructionScreen(currentScreenData);
                case 'sentence_completion':
                  return _buildSentenceCompletionScreen(currentScreenData);
                case 'word_choices':
                  return _buildWordChoicesScreen(currentScreenData);
                default:
                  return Container();
              }
            }(),
          ),
        ),
      ),
    );
  }
}
