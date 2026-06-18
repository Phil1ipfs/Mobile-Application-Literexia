import 'package:flutter/material.dart';
import 'dart:async';
import '../features/assessments/ui/reading_comprehension_screen.dart';
import 'package:provider/provider.dart';
import '../features/assessments/logic/assessment_provider.dart';
import '../features/settings/provider/tts_provider.dart';
import 'package:literexia/features/assessments/models/assessment_model.dart';
import '../features/assessments/ui/pre_assessment_result_screen.dart';

class ReadingComprehensionTutorial extends StatefulWidget {
  const ReadingComprehensionTutorial({Key? key}) : super(key: key);

  @override
  State<ReadingComprehensionTutorial> createState() =>
      _ReadingComprehensionTutorialState();
}

class _ReadingComprehensionTutorialState
    extends State<ReadingComprehensionTutorial> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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

  // Tutorial screens data based on your images
  final List<Map<String, dynamic>> _tutorialScreens = [
    {
      'type': 'passage_screen',
      'title': '"Sino ang Tumatakbo?"',
      'passage':
          'Basahin muna ang tanong na katulad ng halimbawa na nasa itaas.',
      'text':
          'Basasahin muna ang tanong na katulad ng halimbawa na nasa itaas.',
    },
    {
      'type': 'question_screen',
      'text':
          'Tukuyin ang angkop na sagot sa pamamagitan ng pag type na halimbawa na nasa itaas.',
      'placeholder': 'Type you answer here.....',
      'instruction':
          'Ito ang text input field kung saan mo itatype ang inyong sagot sa tanong na nasa passage.',
    },
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ttsProvider = Provider.of<TTSProvider>(context, listen: false);

    if (!_ttsStarted) {
      _ttsStarted = true;
      final texts = _tutorialScreens
          .map((s) => s['text'] is String ? s['text'] as String : '')
          .where((t) => t.isNotEmpty)
          .toList();
      _ttsProvider?.preloadPhrases(texts);
      _speakCurrent();
    }
  }

  // Narrate the current screen. speakText() auto-stops the previous clip, so
  // tapping Magpatuloy quickly never overlaps.
  void _speakCurrent() {
    final text = _tutorialScreens[_currentScreen]['text'];
    if (text is String && text.isNotEmpty) {
      _ttsProvider?.speakText(text);
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
      _speakCurrent();
    }
  }

  Future<void> _finishTutorial() async {
    final provider = Provider.of<AssessmentProvider>(context, listen: false);
    print('[RC_Tutorial] ===== STARTING TUTORIAL FINISH =====');
    print('[RC_Tutorial] Provider accessed successfully');

    // Assessment should already be loaded from WordRecognitionScreen
    if (provider.assessment == null ||
        (provider.assessment?.questions.isEmpty ?? true)) {
      print('[RC_Tutorial] Assessment not loaded, attempting to load...');
      try {
        await provider.loadPreAssessment();
        print('[RC_Tutorial] Assessment loaded successfully');
      } catch (e) {
        print('[RC_Tutorial] Failed to load assessment: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load assessment data: $e')),
          );
        }
        return;
      }
    } else {
      print('[RC_Tutorial] Assessment already loaded with ${provider.assessment?.questions.length ?? 0} questions');
    }

    print(
        '[RC_Tutorial] Total questions in provider: ${provider.assessment?.questions.length ?? 0}');

    // Debug all question IDs to understand the pattern
    final allQuestions = provider.assessment?.questions ?? [];
    print(
        '[RC_Tutorial] All question IDs: ${allQuestions.map((q) => q.questionId).toList()}');

    // Collect RC questions with more flexible pattern matching
    List<Question> rcQuestions = [];
    try {
      // Try multiple pattern matching strategies
      rcQuestions = allQuestions.where((q) {
        final id = q.questionId.toLowerCase();
        // More flexible RC question matching
        return id.startsWith('rc_') ||
            id.contains('reading') ||
            id.contains('comprehension');
      }).toList();

      print(
          '[RC_Tutorial] RC questions found with flexible matching: ${rcQuestions.map((q) => q.questionId).toList()}');

      // If flexible matching fails, try exact pattern
      if (rcQuestions.isEmpty) {
        rcQuestions = allQuestions
            .where((q) => RegExp(r'^RC_\d{3}$').hasMatch(q.questionId))
            .toList();
        print(
            '[RC_Tutorial] RC questions found with exact pattern: ${rcQuestions.map((q) => q.questionId).toList()}');
      }

      // Sort by questionId
      rcQuestions.sort((a, b) {
        // Extract numbers for sorting, handle different formats
        final aMatch = RegExp(r'(\d+)').firstMatch(a.questionId);
        final bMatch = RegExp(r'(\d+)').firstMatch(b.questionId);
        final aNum = int.tryParse(aMatch?.group(1) ?? '0') ?? 0;
        final bNum = int.tryParse(bMatch?.group(1) ?? '0') ?? 0;
        return aNum.compareTo(bNum);
      });

      print(
          '[RC_Tutorial] Sorted RC questions: ${rcQuestions.map((q) => q.questionId).toList()}');
    } catch (e) {
      print('[RC_Tutorial] Error filtering RC questions: $e');
    }

    if (rcQuestions.isEmpty) {
      print('[RC_Tutorial] No RC questions found!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No Reading Comprehension questions found in assessment data.')),
        );
      }
      return;
    }

    final firstQuestion = rcQuestions.first;
    print('[RC_Tutorial] First RC question: ${firstQuestion.questionId}');
    print('[RC_Tutorial] First question data: ${firstQuestion.toMap()}');

    // Validate question structure
    final hasPassages =
        firstQuestion.passages != null && firstQuestion.passages!.isNotEmpty;
    final hasSentenceQuestions = firstQuestion.sentenceQuestions != null &&
        firstQuestion.sentenceQuestions!.isNotEmpty;

    print(
        '[RC_Tutorial] Question validation - hasPassages: $hasPassages, hasSentenceQuestions: $hasSentenceQuestions');

    if (!hasPassages && !hasSentenceQuestions) {
      print('[RC_Tutorial] Question has no passages or sentence questions!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Reading Comprehension question is missing required data (passages or questions).')),
        );
      }
      return;
    }

    if (!mounted) return;

    print('[RC_Tutorial] Navigating to ReadingComprehensionScreen...');

    // Navigate with proper provider context - use pushReplacement to replace tutorial
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (newContext) => ChangeNotifierProvider.value(
            value: provider,
            child: ReadingComprehensionScreen(
              question: firstQuestion,
              assessmentType: 'pre_assessment',
              onComplete: () {
                print('[RC_Tutorial] ReadingComprehension completed');
                // Navigate to result screen or back to home
                if (mounted) {
                  // Navigate to result screen instead of popping back
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => PreAssessmentResultScreen(
                        readingLevel: provider.readingLevel ?? 'Developing',
                        score: provider.score,
                        totalQuestions: provider.assessment?.questions.length ?? 0,
                        readingPercentage: provider.readingPercentage,
                        assessmentType: 'pre-assessment',
                        assessmentId: 'PRE_ASSESSMENT_001',
                      ),
                    ),
                  );
                }
              },
              onAnswerSubmitted: (String answer) {
                print('[RC_Tutorial] Answer submitted: $answer');
                try {
                  provider.answerCurrentQuestion(answer);
                } catch (e) {
                  print('[RC_Tutorial] Error submitting answer: $e');
                }
              },
              handleAllRcQuestions: true,
              rcQuestionsList: rcQuestions,
            ),
          ),
        ),
      );
    }

    print('[RC_Tutorial] ===== TUTORIAL FINISH COMPLETE =====');
  }

  @override
  void dispose() {
    _ttsProvider?.stopSpeaking();
    _timer?.cancel();
    _animationController.dispose();
    _typewriterController.dispose();
    super.dispose();
  }

  Widget _buildPassageScreen(Map<String, dynamic> screen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),

        // Title
        Text(
          screen['title'],
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9D56E),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 40),

        // Explanation text with typewriter effect
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
        const SizedBox(height: 80),

        // Text input field mockup
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF9D56E), width: 2),
          ),
          child: Text(
            screen['placeholder'],
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),

        const SizedBox(height: 60),

        // Instruction text with typewriter effect
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
    return SizedBox(
      width: 310,
      height: 50,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(197, 255, 204, 0),
              offset: const Offset(0, 4),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
          borderRadius: BorderRadius.circular(10),
        ),
        child: ElevatedButton(
          onPressed: _currentScreen == _tutorialScreens.length - 1
              ? _finishTutorial
              : _nextScreen,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFFFCC00),
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
              case 'passage_screen':
                return _buildPassageScreen(currentScreenData);
              case 'question_screen':
                return _buildQuestionScreen(currentScreenData);
              default:
                return Container();
            }
          }(),
        ),
      ),
    );
  }
}
