import 'package:flutter/material.dart';
import 'package:literexia/Tutorial/Phonological_tutorial.dart';
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
  // Typewriter animation
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  String _currentText = '';
  bool _showButton = false;

  int _currentScreen = 0;

  // Tutorial screens data
  final List<Map<String, dynamic>> _tutorialScreens = [
    {
      'type': 'progress',
      'progress': '5/5',
      'text':
          'Ito ay progress tracker na kung saan makikita mo kung nasa pang ilang tanong kana.',
    },
    {
      'type': 'instruction',
      'text': 'Tukuyin kung ano ang nasa larawan para ikaw ay may Ideya.',
    },
    {
      'type': 'question',
      'title': '"Tukuyin ang nasa larawan?"',
      'text': 'Basahin muna ang tanong na katulad ng halimbawa na nasa itaas.',
    },
    {
      'type': 'audio',
      'text': 'Pindutin lamang ang audio kapag ikaw ay ready na sumagot.',
    },
    {
      'type': 'answer_choices',
      'choices': ['A', 'B', 'C'],
      'text': 'Pumili ng sagot pindutin lamang ang gaya ng nasa itaas.',
    },
    {
      'type': 'check_answer',
      'text':
          'Pindutin ang button na kulay green kapag ikaw ay sigurado na sa iyong sagot.',
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
    final screen = _tutorialScreens[_currentScreen];
    _currentText = screen['text'] is String ? screen['text'] as String : '';

    _typewriterAnimation = IntTween(
      begin: 0,
      end: _currentText.length,
    ).animate(CurvedAnimation(
      parent: _typewriterController,
      curve: Curves.linear,
    ));

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
    final assessmentProvider = AssessmentProvider();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const PhonologicalTutorial(),
      ),
    );
  }

  @override
  void dispose() {
    _typewriterController.dispose();
    super.dispose();
  }

  Widget _buildProgressScreen(Map<String, dynamic> screen) {
    return Column(
      children: [
        const SizedBox(height: 60),
        // Progress Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9D56E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      screen['progress'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 120),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _currentText.substring(0, _typewriterAnimation.value),
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
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

  Widget _buildInstructionScreen(Map<String, dynamic> screen) {
    return Column(
      children: [
        const SizedBox(height: 100),
        // Penguin Character
        Container(
          width: 150,
          height: 150,
          child: Image.asset(
            'assets/images/icons8-igloo-64.png', // You may need to replace with PNG/JPG
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pets,
                  size: 80,
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 80),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _currentText.substring(0, _typewriterAnimation.value),
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  letterSpacing: 1,
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

  Widget _buildQuestionScreen(Map<String, dynamic> screen) {
    return Column(
      children: [
        const SizedBox(height: 100),
        // Question Title
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
        const SizedBox(height: 120),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _currentText.substring(0, _typewriterAnimation.value),
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  letterSpacing: 1,
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

  Widget _buildAudioScreen(Map<String, dynamic> screen) {
    return Column(
      children: [
        const SizedBox(height: 100),
        // Audio Button
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF9D56E),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(
            Icons.volume_up,
            size: 40,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          'Pakinggan',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 120),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _currentText.substring(0, _typewriterAnimation.value),
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  letterSpacing: 1,
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
      children: [
        const SizedBox(height: 100),
        // Answer choice buttons
        Column(
          children: [
            _buildChoiceButton(screen['choices'][0]),
            const SizedBox(height: 20),
            _buildChoiceButton(screen['choices'][1]),
            const SizedBox(height: 20),
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
                _currentText.substring(0, _typewriterAnimation.value),
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  letterSpacing: 1,
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

  Widget _buildCheckAnswerScreen(Map<String, dynamic> screen) {
    return Column(
      children: [
        const SizedBox(height: 150),
        // Green "TIGNAN ANG SAGOT" Button
        Container(
          width: 350,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF00E10F),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(204, 0, 225, 15),
                offset: const Offset(0, 5),
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'TIGNAN ANG SAGOT',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 120),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _currentText.substring(0, _typewriterAnimation.value),
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
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
      width: 250,
      height: 80,
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF00E10F),
          width: 3,
        ),
        borderRadius: BorderRadius.circular(15),
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF9D56E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.volume_up,
                size: 20,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      width: 300,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(197, 255, 193, 7),
            offset: const Offset(0, 5),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextButton(
        onPressed: _currentScreen == _tutorialScreens.length - 1
            ? _finishTutorial
            : _nextScreen,
        child: Text(
          'Mag Patuloy',
          style: TextStyle(
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
          duration: const Duration(milliseconds: 300),
          child: KeyedSubtree(
            key: ValueKey(_currentScreen),
            child: () {
              switch (currentScreenData['type']) {
                case 'progress':
                  return _buildProgressScreen(currentScreenData);
                case 'instruction':
                  return _buildInstructionScreen(currentScreenData);
                case 'question':
                  return _buildQuestionScreen(currentScreenData);
                case 'audio':
                  return _buildAudioScreen(currentScreenData);
                case 'answer_choices':
                  return _buildAnswerChoicesScreen(currentScreenData);
                case 'check_answer':
                  return _buildCheckAnswerScreen(currentScreenData);
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
