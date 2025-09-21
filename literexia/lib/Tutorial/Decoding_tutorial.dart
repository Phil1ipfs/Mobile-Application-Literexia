import 'package:flutter/material.dart';
import 'dart:async';
import '../features/assessments/ui/DecodingScreen.dart';
import 'package:provider/provider.dart';
import '../features/assessments/logic/assessment_provider.dart';
import '../features/settings/provider/theme_provider.dart';
import '../features/settings/provider/tts_provider.dart';
import 'package:lottie/lottie.dart';
import '../core/theme/app_theme.dart';
import 'dart:math' as Math;

// Loading screen for transition to DecodingScreen
class LoadingScreen extends StatefulWidget {
  final String assessmentId;
  final AssessmentProvider provider;
  final bool isPreAssessment;

  const LoadingScreen({
    Key? key,
    required this.assessmentId,
    required this.provider,
    required this.isPreAssessment,
  }) : super(key: key);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  String _displayText = "";
  int _currentIndex = 0;
  Timer? _typewriterTimer;
  bool _isTypingComplete = false;
  bool _showAnimation = false;
  bool _lottieError = false;

  late AnimationController _fadeController;

  // TTS related variables
  bool _isTTSPlaying = false;
  bool _isTTSLoading = false;

  // Full text for typewriter and TTS
  final String _fullText = "Magpatuloy tayo sa susunod na yugto...";

  TTSProvider? _ttsProvider;
  ThemeProvider? _themeProvider;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 20),
    )..repeat(reverse: true);

    // Start typewriter effect after a short delay
    Future.delayed(const Duration(milliseconds: 20), () {
      if (mounted) {
        _startTypewriterEffect();
        setState(() {
          _showAnimation = true;
        });
        _fadeController.forward();
      }
    });

    // Initialize providers after a short delay to ensure context is available
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
        _themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      }
    });

    // Auto-navigate after loading is complete (3 seconds)
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateToDecodingScreen();
      }
    });
  }

  void _startTypewriterEffect() {
    // Cancel any existing timer
    _typewriterTimer?.cancel();

    // Reset the text state
    setState(() {
      _displayText = "";
      _currentIndex = 0;
      _isTypingComplete = false;
    });

    // Start a timer to add one character at a time
    _typewriterTimer = Timer.periodic(Duration(milliseconds: 30), (timer) {
      if (_currentIndex < _fullText.length) {
        setState(() {
          _displayText = _fullText.substring(0, _currentIndex + 1);
          _currentIndex++;
        });
      } else {
        // Typing is complete
        timer.cancel();
        setState(() {
          _isTypingComplete = true;
        });
      }
    });
  }

  void _navigateToDecodingScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: widget.provider),
            ChangeNotifierProvider.value(
                value: Provider.of<ThemeProvider>(context, listen: false)),
            ChangeNotifierProvider.value(
                value: Provider.of<TTSProvider>(context, listen: false)),
          ],
          child: DecodingScreen(
            assessmentId: widget.assessmentId,
            isPreAssessment: widget.isPreAssessment,
          ),
        ),
      ),
    );
  }

  // Load Lottie animation with error handling
  Widget _loadLottieAnimation() {
    try {
      return Lottie.asset(
        'assets/animations/mascotte-design.json',
        width: 300,
        height: 300,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading Lottie animation: $error');
          setState(() {
            _lottieError = true;
          });
          return _buildAnimatedPenguin();
        },
      );
    } catch (e) {
      print('Exception loading Lottie animation: $e');
      return _buildAnimatedPenguin();
    }
  }

  // Improved animated penguin as fallback
  Widget _buildAnimatedPenguin() {
    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Transform.translate(
              offset:
                  Offset(0, 6 * Math.sin(_fadeController.value * 2 * Math.pi)),
              child: Container(
                width: 130,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF00394D),
                  borderRadius: BorderRadius.circular(65),
                ),
                child: Stack(
                  children: [
                    // White belly
                    Positioned(
                      bottom: 0,
                      left: 12,
                      child: Container(
                        width: 106,
                        height: 106,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(53),
                            bottomRight: Radius.circular(53),
                          ),
                        ),
                      ),
                    ),
                    // Eyes
                    Positioned(
                      top: 32,
                      left: 28,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 3),
                        ),
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 32,
                      right: 28,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 3),
                        ),
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Beak
                    Positioned(
                      top: 65,
                      left: 45,
                      child: Container(
                        width: 40,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    // Wings
                    Positioned(
                      top: 57,
                      left: 0,
                      child: Transform.rotate(
                        angle: -0.2 - (0.1 * _fadeController.value),
                        child: Container(
                          width: 32,
                          height: 65,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00394D),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 57,
                      right: 0,
                      child: Transform.rotate(
                        angle: 0.2 + (0.1 * _fadeController.value),
                        child: Container(
                          width: 32,
                          height: 65,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00394D),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    // Feet
                    Positioned(
                      bottom: 0,
                      left: 32,
                      child: Container(
                        width: 24,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 32,
                      child: Container(
                        width: 24,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Speech bubble with typewriter text
  Widget _buildSpeechBubble(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF4D4D4D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber, width: 2.0),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Century Gothic',
          letterSpacing: 0.0,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth - 48;

    return Scaffold(
      backgroundColor: AppTheme.primaryDarkBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 1),

              // Speech bubble with typewriter text
              _buildSpeechBubble(_displayText),

              // Lottie animation or fallback penguin animation
              Expanded(
                flex: 3,
                child: AnimatedOpacity(
                  opacity: _showAnimation ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Center(
                    child: SizedBox(
                      width: containerWidth,
                      height: 200,
                      child: _lottieError
                          ? _buildAnimatedPenguin()
                          : _loadLottieAnimation(),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _fadeController.dispose();

    // Stop TTS when leaving the screen
    _ttsProvider?.stopSpeaking();
    super.dispose();
  }
}

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
          'Ang Kahon na nasa itaas ay ang inyong pag lalagyan ng letra para masagot ang katanungan.',
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
    // Get existing providers from context to avoid disposal issues
    final assessmentProvider =
        Provider.of<AssessmentProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final ttsProvider = Provider.of<TTSProvider>(context, listen: false);

    // Load pre-assessment data
    assessmentProvider.loadPreAssessment();

    // Navigate to LoadingScreen which will then navigate to DecodingScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AssessmentProvider>.value(
              value: assessmentProvider,
            ),
            ChangeNotifierProvider<ThemeProvider>.value(
              value: themeProvider,
            ),
            ChangeNotifierProvider<TTSProvider>.value(
              value: ttsProvider,
            ),
          ],
          child: LoadingScreen(
            assessmentId: 'PRE_ASSESSMENT_001',
            provider: assessmentProvider,
            isPreAssessment: true, // This is pre-assessment
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

  // Helper method to calculate pill position similar to AlphabetKnowledgeScreen
  double _calculatePillPosition(int current, int total) {
    // Get the available width (screen width minus margins and pill width)
    final screenWidth = MediaQuery.of(context).size.width;
    final totalWidth = screenWidth - 80; // 40px margin on each side
    final progressRatio = current / total;
    final pillWidth = 80.0;
    final pillPosition = (totalWidth - pillWidth) * progressRatio;

    // Handle edge cases
    if (progressRatio < 0.1) {
      return 0;
    } else if (progressRatio > 0.9) {
      return totalWidth - pillWidth;
    } else {
      return pillPosition;
    }
  }

  Widget _buildProgressScreen(Map<String, dynamic> screen) {
    // Parse the progress string to get current and total
    final progressText = screen['progress'] as String;
    final parts = progressText.split('/');
    final current = int.tryParse(parts[0]) ?? 1;
    final total = int.tryParse(parts[1]) ?? 5;

    return Column(
      children: [
        const SizedBox(height: 60),
        // Progress Bar with overlap indicator
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 40),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background bar
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC00),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromARGB(197, 255, 204, 0),
                      blurRadius: 0,
                      spreadRadius: 0,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
              ),
              // Progress bar
              FractionallySizedBox(
                widthFactor: current / total,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFCC00),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromARGB(197, 255, 204, 0),
                        offset: Offset(0, 4),
                        blurRadius: 0,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
              // Overlapping progress pill
              Positioned(
                left: _calculatePillPosition(current, total),
                top: -10,
                child: Container(
                  height: 40,
                  width: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFCC00),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromARGB(197, 255, 204, 0),
                        blurRadius: 0,
                        spreadRadius: 0,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      screen['progress'],
                      style: const TextStyle(
                        fontSize: 14,
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
                _displayedText,
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
                boxShadow: (screen['letters'] != null &&
                    screen['letters'].contains('D') &&
                    screen['letters'].contains('R') &&
                    screen['letters'].contains('O') &&
                    screen['letters'].contains('P') &&
                    screen['letters'].length == 4)
                    ? null
                    : [
                        BoxShadow(
                          color: const Color.fromARGB(197, 249, 213, 110),
                          offset: const Offset(0, 4),
                          blurRadius: 0,
                          spreadRadius: 0,
                        ),
                      ],
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
                  fontSize: 17,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  letterSpacing: 1.2,
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
                  fontSize: 17,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  letterSpacing: 1.2,
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
        // Igloo image
        Container(
          width: 150,
          height: 150,
          child: Image.asset(
            'assets/images/icons8-igloo-64.png',
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.home,
                  size: 80,
                  color: Colors.white,
                ),
              );
            },
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
                  fontSize: 17,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  letterSpacing: 1.2,
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
      children: [
        const SizedBox(height: 150),
        // Green "TIGNAN ANG SAGOT" Button
        Container(
          width: 250,
          height: 60,
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
          child: Center(
            child: Text(
              screen['buttonText'],
              style: const TextStyle(
                fontSize: 18,
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
                _displayedText,
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
