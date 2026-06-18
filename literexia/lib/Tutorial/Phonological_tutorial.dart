import 'package:flutter/material.dart';
import 'package:literexia/Tutorial/WordRecognition_tutorial.dart';
import 'dart:async';
import '../features/assessments/ui/PhonologicalMatching.dart';
import 'package:provider/provider.dart';
import '../features/assessments/logic/assessment_provider.dart';
import '../features/settings/provider/theme_provider.dart';
import '../features/settings/provider/tts_provider.dart';

class PhonologicalTutorial extends StatefulWidget {
  const PhonologicalTutorial({Key? key}) : super(key: key);

  @override
  State<PhonologicalTutorial> createState() => _PhonologicalTutorialState();
}

class _PhonologicalTutorialState extends State<PhonologicalTutorial>
    with TickerProviderStateMixin {
  // Typewriter animation
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  String _displayedText = '';
  bool _showButton = false;

  int _currentScreen = 0;
  Timer? _timer;

  // TTS narration (cached ref so dispose is safe)
  TTSProvider? _ttsProvider;
  bool _ttsStarted = false;

  // Tutorial screens data based on the images
  final List<Map<String, dynamic>> _tutorialScreens = [
    {
      'type': 'instruction',
      'text':
          'Pakinggan ang tunog at piliin ang katugma nito.',
      'subtext':
          'Basahin ang tanong na katulad ng halimbawa na nasa itaas.',
      'ttsText':
          'Basahin ang tanong na katulad ng halimbawa na nasa itaas.',
    },
    {
      'type': 'audio_button',
      'text':
          'Pindutin ang audio icon para mapakinggan ang tunog.',
    },
    {
      'type': 'multiple_choice',
      'letters': ['H', 'T', 'N', 'L'],
      'text': 'Piliin ang tamang sagot \n batay sa iyong narinig.',
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ttsProvider = Provider.of<TTSProvider>(context, listen: false);

    if (!_ttsStarted) {
      _ttsStarted = true;
      final texts = _tutorialScreens
          .map((s) {
            final t = s['ttsText'] ?? s['text'];
            return t is String ? t : '';
          })
          .where((t) => t.isNotEmpty)
          .toList();
      _ttsProvider?.preloadPhrases(texts);
      _speakCurrent();
    }
  }

  // Narrate the current screen. speakText() auto-stops the previous clip, so
  // tapping Magpatuloy quickly never overlaps.
  void _speakCurrent() {
    final screen = _tutorialScreens[_currentScreen];
    final textToSpeak = screen['ttsText'] ?? screen['text'];
    if (textToSpeak is String && textToSpeak.isNotEmpty) {
      _ttsProvider?.speakText(textToSpeak);
    }
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
          _displayedText = currentText.substring(0, _typewriterAnimation.value > currentText.length ? currentText.length : _typewriterAnimation.value);
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
      _speakCurrent();
    }
  }

  void _finishTutorial() {
    // Create a new AssessmentProvider instance
    final assessmentProvider = AssessmentProvider();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const WordRecognitionTutorial(),
      ),
    );
  }

  @override
  void dispose() {
    _ttsProvider?.stopSpeaking();
    _timer?.cancel();
    _typewriterController.dispose();
    super.dispose();
  }

  Widget _buildInstructionScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Main instruction text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _displayedText,
                style: const TextStyle(
                  fontSize: 20,
                  color: Color(0xFFF9D56E),
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
        const SizedBox(height: 60),
        // Subtext
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            screen['subtext'],
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.5,
              letterSpacing: 2.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Spacer(),
        if (_showButton) _buildContinueButton(),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildAudioButtonScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Audio button - show immediately without typewriter
        Container(
          width: 200,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.amberAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.volume_up,
                  size: 50,
                  color: Colors.black,
                ),
                SizedBox(width: 10),
                // Audio waveform representation
                Icon(
                  Icons.graphic_eq,
                  size: 50,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 60),
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

  Widget _buildMultipleChoiceScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 50),
        // Letter choice buttons - show immediately without typewriter
        Column(
          children: screen['letters'].map<Widget>((letter) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 200,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: const Color(0xFFF9D56E),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  letter,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 60),
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
                case 'audio_button':
                  return _buildAudioButtonScreen(currentScreenData);
                case 'multiple_choice':
                  return _buildMultipleChoiceScreen(currentScreenData);
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
