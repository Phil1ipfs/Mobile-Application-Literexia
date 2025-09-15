import 'package:flutter/material.dart';
import 'dart:async';
import '../features/assessments/ui/DecodingScreen.dart';
import 'package:provider/provider.dart';
import '../features/assessments/logic/assessment_provider.dart';
import '../features/settings/provider/theme_provider.dart';
import '../features/settings/provider/tts_provider.dart';

class DecodingTutorial extends StatefulWidget {
  const DecodingTutorial({Key? key}) : super(key: key);

  @override
  State<DecodingTutorial> createState() => _DecodingTutorialState();
}

class _DecodingTutorialState extends State<DecodingTutorial>
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
      'type': 'progress',
      'progress': '5/5',
      'text':
          'Ito ay progress tracker na kung saan makikita mo kung nasa pang ilang tanong kana.',
    },
    {
      'type': 'question',
      'letters': ['D', 'R', 'O', 'P'],
      'text':
          'Ang Box na nasa itaas ay ang inyong pag lalagyan ng letra para masagot ang katanungan.',
    },
    {
      'type': 'instruction',
      'title': '"Tukuyin ang nasa larawan?"',
      'text': 'Basahin muna ang tanong na katulad ng halimbawa na nasa itaas.',
    },
    {
      'type': 'alphabet_hint',
      'text':
          'Ang larawan na iyan ay isang pahiwatig para mag ka idea kung ano ba ang tamang sagot.',
      'placeholder': 'Display one sample image here in alphabet knowledge.',
    },
    {
      'type': 'main_question',
      'letters': ['D', 'R', 'A', 'G'],
      'text':
          'Ang apat na nasa itaas ay ang inyong pag pipilian para masagot ang katanungan.',
    },
    {
      'type': 'success',
      'buttonText': 'TIGNAN ANG SAGOT',
      'text':
          'Pindutin ang button na kulay green kapag ikaw ay sigurado na sa inyong sagot.',
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) {
                final provider = AssessmentProvider();
                // Initialize the provider to ensure it's ready
                provider.loadPreAssessment();
                return provider;
              },
            ),
            ChangeNotifierProvider(create: (_) => TTSProvider()),
            ChangeNotifierProvider(
              create: (context) {
                final themeProvider = ThemeProvider();
                final ttsProvider =
                    Provider.of<TTSProvider>(context, listen: false);
                themeProvider.setTTSProvider(ttsProvider);
                return themeProvider;
              },
            ),
          ],
          child: const DecodingScreen(
            assessmentId: 'PRE_ASSESSMENT_001',
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    _typewriterController.dispose();
    super.dispose();
  }

  Widget _buildProgressScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Progress bar
        Container(
          width: 300,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF9D56E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              screen['progress'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _displayedText,
                style: const TextStyle(
                  fontSize: 16,
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

  Widget _buildQuestionScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Letter boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: screen['letters'].map<Widget>((letter) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: screen['type'] == 'main_question'
                    ? const Color(0xFFF9D56E)
                    : Colors.transparent,
                border: Border.all(
                  color: const Color(0xFFF9D56E),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: screen['type'] == 'main_question'
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _displayedText,
                style: const TextStyle(
                  fontSize: 16,
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

  Widget _buildInstructionScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Question title
        Text(
          screen['title'],
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9D56E),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _displayedText,
                style: const TextStyle(
                  fontSize: 16,
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

  Widget _buildAlphabetHintScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Placeholder for image
        Container(
          width: 200,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              screen['placeholder'],
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              return Text(
                _displayedText,
                style: const TextStyle(
                  fontSize: 16,
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

  Widget _buildSuccessScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        // Green button
        Container(
          width: 200,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              screen['buttonText'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 60),
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
              case 'progress':
                return _buildProgressScreen(currentScreenData);
              case 'question':
                return _buildQuestionScreen(currentScreenData);
              case 'instruction':
                return _buildInstructionScreen(currentScreenData);
              case 'alphabet_hint':
                return _buildAlphabetHintScreen(currentScreenData);
              case 'main_question':
                return _buildQuestionScreen(currentScreenData);
              case 'success':
                return _buildSuccessScreen(currentScreenData);
              default:
                return Container();
            }
          }(),
        ),
      ),
    );
  }
}
