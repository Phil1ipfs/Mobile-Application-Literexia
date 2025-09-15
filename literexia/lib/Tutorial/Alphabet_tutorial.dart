import 'package:flutter/material.dart';
import 'dart:async';
import '../features/assessments/ui/AlphabetKnowledgeScreen.dart';
import '../features/assessments/logic/assessment_provider.dart';

class AlphabetTutorial extends StatefulWidget {
  const AlphabetTutorial({Key? key}) : super(key: key);

  @override
  State<AlphabetTutorial> createState() => _AlphabetTutorialState();
}

class _AlphabetTutorialState extends State<AlphabetTutorial>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
      'title': '"Anong ang katumbas na maliit na letra?"',
      'text': 'Basahin muna ang tanong na katulad ng halimbawa na nasa itaas.',
    },
    {
      'type': 'letter_display',
      'letter': 'a',
      'text':
          'At tignan kung ano ang pahiwatig tulad ng halimbawa na nasa itaas',
    },
    {
      'type': 'answer_choices',
      'choices': ['Sagot A', 'Sagot B', 'Sagot C'],
      'text':
          'Pumili ng tamang sagot sa tatlong choices na inyong makikita, tulad ng halimbawa na nasa itaas.',
    }
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Initialize typewriter controller
    _typewriterController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _animationController.forward();

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

  void _startAutoAdvance() {
    // Remove auto-advance since we want manual control after typewriter
  }

  void _nextScreen() {
    if (_currentScreen < _tutorialScreens.length - 1) {
      setState(() {
        _currentScreen++;
      });
      _animationController.reset();
      _animationController.forward();
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
              )),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    _typewriterController.dispose();
    super.dispose();
  }

  Widget _buildInstructionScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Question title
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
                  fontWeight: FontWeight.w500,
                  height: 1.5,
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

  Widget _buildLetterDisplayScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Large letter display
        Container(
          width: 120,
          height: 120,
          child: Center(
            child: Text(
              screen['letter'],
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF9D56E),
              ),
            ),
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
                  fontWeight: FontWeight.w500,
                  height: 1.5,
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

  Widget _buildAnswerChoicesScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Answer choice buttons
        Column(
          children: [
            // First row with two buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChoiceButton(screen['choices'][0]),
                const SizedBox(width: 20),
                _buildChoiceButton(screen['choices'][1]),
              ],
            ),
            const SizedBox(height: 20),
            // Second row with one centered button
            _buildChoiceButton(screen['choices'][2]),
          ],
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
                  fontWeight: FontWeight.w500,
                  height: 1.5,
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
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFFF9D56E),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9D56E),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: 310,
      height: 50,
      child: ElevatedButton(
        onPressed: _currentScreen == _tutorialScreens.length - 1
            ? _finishTutorial
            : _nextScreen,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFFFCC00),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 5,
        ),
        child: Text(
          _currentScreen == _tutorialScreens.length - 1
              ? 'Mag Patuloy'
              : 'Mag Patuloy',
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
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: () {
            switch (currentScreenData['type']) {
              case 'instruction':
                return _buildInstructionScreen(currentScreenData);
              case 'letter_display':
                return _buildLetterDisplayScreen(currentScreenData);
              case 'answer_choices':
                return _buildAnswerChoicesScreen(currentScreenData);
              default:
                return Container();
            }
          }(),
        ),
      ),
    );
  }
}
