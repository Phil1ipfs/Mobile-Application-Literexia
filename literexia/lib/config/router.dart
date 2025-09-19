// lib/config/router.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:literexia/screens/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/pre_login_screen.dart'; // Add pre-login screen import

// ─── CORE SCREENS ─────────────────────────────────────────────────────────────
import 'package:literexia/screens/home_screen.dart';
import 'package:literexia/screens/login_screen.dart'; // Added login screen
import '../Tutorial/Login_tutorial.dart'; // Added login tutorial

// ─── CATEGORY SCREENS ─────────────────────────────────────────────────────────
import '../features/assessments/ui/AlphabetKnowledgeScreen.dart';
import '../features/assessments/ui/DecodingScreen.dart';
import '../features/assessments/ui/WordRecognitionScreen.dart';

// ─── ASSESSMENT FLOW ──────────────────────────────────────────────────────────
import '../features/assessments/ui/pre_assessment_result_screen.dart';
import '../features/assessments/ui/pre_assessment_intro_screen.dart';

import '../screens/student_reflect_screen.dart';
import '../features/assessments/ui/PhonologicalMatching.dart';
import '../features/assessments/logic/assessment_provider.dart';
import '../features/assessments/models/assessment_model.dart';
import '../features/assessments/ui/reading_comprehension_screen.dart';

class AppRouter {
  // ─── CORE ROUTES ────────────────────────────────────────────────────────────
  static const String splash = '/';
  static const String preLogin = '/pre-login'; // Add pre-login route
  static const String loginTutorial =
      '/login-tutorial'; // Added login tutorial route
  static const String login = '/login'; // Added login route
  static const String home = '/home';
  static const String lesson = '/lesson';
  static const String userManagement = '/user-management';
  static const String assessment = '/assesssment';
  static const String profile = '/profile';
  static const String studentReflect = '/student-reflect';
  static const String phonological = '/PHONOLOGICAL';

  // ─── ASSESSMENT ROUTES ────────────────────────────────────────────────────────
  static const String preAssessment = '/pre-assessment';
  static const String preAssessmentQuestion = '/pre-assessment-question';
  static const String mainAssessmentQuestion = '/main-assessment-question';
  static const String preAssessmentResult = '/pre-assessment-result';
  static const String preAssessmentIntro = '/pre-assessment-intro';
  static const String categoryAssessment = '/category-assessment';

  // ─── CATEGORY ROUTES ──────────────────────────────────────────────────────────
  static const String phonologicalAwareness = '/phonological-awareness';
  static const String alphabetKnowledge = '/alphabet-knowledge';
  static const String decoding = '/decoding';
  static const String wordRecognition = '/word-recognition';
  static const String readingComprehension = '/reading-comprehension';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ─── CORE ────────────────────────────────────────────────────────────────
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case preLogin:
        return MaterialPageRoute(builder: (_) => const PreLoginScreen());

      case loginTutorial:
        return MaterialPageRoute(builder: (_) => const LoginTutorial());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case studentReflect:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => StudentReflectScreen(
            assessmentType: args['assessmentType'] ?? '',
            assessmentId: args['assessmentId'],
            score: args['score'],
            totalQuestions: args['totalQuestions'],
            onComplete: args['onComplete'],
          ),
        );

      case preAssessmentIntro:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => PreAssessmentIntroScreen(
            assessmentId: args['assessmentId'] ?? 1,
          ),
        );

      case preAssessmentResult:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => PreAssessmentResultScreen(
            readingLevel: args['readingLevel'] ?? 'Undefined',
            score: args['score'] ?? 0,
            totalQuestions: args['totalQuestions'] ?? 5,
            readingPercentage: args['readingPercentage'],
            assessmentType: args['assessmentType'] ?? 'pre-assessment',
            assessmentId: args['assessmentId'],
          ),
        );

      case home:
        // Updated to handle the forceRefresh flag and readingLevel
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final forceRefresh = args['forceRefresh'] ?? false;
        return MaterialPageRoute(
          builder: (_) => HomeScreen(
            forceRefresh: forceRefresh,
          ),
        );

      case readingComprehension:
        final args = settings.arguments as Map<String, dynamic>? ?? {};

        // Handle both direct question passing (for pre-assessment/tutorial)
        // and assessmentId-based navigation (for main assessment)
        if (args['question'] != null) {
          // Direct question passing - used for pre-assessment and tutorials
          return MaterialPageRoute(
            builder: (_) => ReadingComprehensionScreen(
              question: args['question'],
              assessmentType: args['assessmentType'] ?? 'pre_assessment',
              onComplete: args['onComplete'] ?? () {},
              onAnswerSubmitted: args['onAnswerSubmitted'] ?? (String answer) {},
              handleAllRcQuestions: args['handleAllRcQuestions'] ??
                  false, // Default to false for main assessment
              rcQuestionsList: args['rcQuestionsList'], // Pass RC questions list
            ),
          );
        } else {
          // AssessmentId-based navigation - used for main assessment
          // Create a wrapper that loads the assessment and navigates to the first RC question
          return MaterialPageRoute(
            builder: (context) => _ReadingComprehensionWrapper(
              assessmentId: args['assessmentId'] ?? '',
              isPreAssessment: args['isPreAssessment'] ?? false,
              onComplete: args['onComplete'],
              onOptionSelected: args['onOptionSelected'],
              onContinue: args['onContinue'],
            ),
          );
        }

      // ─── CATEGORY ASSESSMENT ROUTES ───────────────────────────────────────────
      case alphabetKnowledge:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (context) {
            // Get AssessmentProvider from context
            final assessmentProvider =
                Provider.of<AssessmentProvider>(context, listen: false);
            return AlphabetKnowledgeScreen(
              assessmentId: args['assessmentId'],
              provider: assessmentProvider,
              onAssessmentComplete: args['onComplete'],
              isPreAssessment: args['isPreAssessment'] ?? false, // Default to main assessment
            );
          },
        );

      case decoding:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => DecodingScreen(
            assessmentId: args['assessmentId'] ?? '',
            onOptionSelected: args['onOptionSelected'],
            onContinue: args['onContinue'],
            isPreAssessment: args['isPreAssessment'] ?? false, // Default to main assessment
          ),
        );

      case wordRecognition:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => WordRecognitionScreen(
            assessmentId: args['assessmentId'] ?? '',
            onOptionSelected: args['onOptionSelected'],
            onContinue: args['onContinue'],
            isPreAssessment: args['isPreAssessment'] ?? false,
          ),
        );

      case phonologicalAwareness:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => PhonologicalMatchingScreen(
            assessmentId: args['assessmentId'] ?? '',
            isPreAssessment: args['isPreAssessment'] ?? false, // Default to main assessment
            onOptionSelected: args['onOptionSelected'],
            onContinue: args['onContinue'],
          ),
        );

      // ─── FALLBACK ────────────────────────────────────────────────────────────
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text(
                'No route defined for ${settings.name}',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          ),
        );
    }
  }
}

// Wrapper class to handle main assessment reading comprehension navigation
class _ReadingComprehensionWrapper extends StatefulWidget {
  final String assessmentId;
  final bool isPreAssessment;
  final Function? onComplete;
  final Function? onOptionSelected;
  final Function? onContinue;

  const _ReadingComprehensionWrapper({
    required this.assessmentId,
    required this.isPreAssessment,
    this.onComplete,
    this.onOptionSelected,
    this.onContinue,
  });

  @override
  State<_ReadingComprehensionWrapper> createState() => _ReadingComprehensionWrapperState();
}

class _ReadingComprehensionWrapperState extends State<_ReadingComprehensionWrapper> {
  @override
  void initState() {
    super.initState();
    _loadAssessmentAndNavigate();
  }

  Future<void> _loadAssessmentAndNavigate() async {
    try {
      // Get the assessment provider
      final assessmentProvider = Provider.of<AssessmentProvider>(context, listen: false);

      // CRITICAL: Clear any existing assessment data to prevent fallback to pre-assessment
      print('[ReadingComprehensionWrapper] Clearing existing assessment data');
      assessmentProvider.resetAssessment();

      // Load the assessment with Reading Comprehension category specified
      print('[ReadingComprehensionWrapper] Loading main assessment: ${widget.assessmentId}');
      await assessmentProvider.loadMainAssessment(
        widget.assessmentId,
        category: 'Reading Comprehension',
      );

      // ENHANCED: Validate that we actually loaded the main assessment
      if (assessmentProvider.assessment == null) {
        print('[ReadingComprehensionWrapper] Failed to load main assessment - assessment is null');
        _handleError('Failed to load main assessment');
        return;
      }

      // Check if this is actually a main assessment (not pre-assessment)
      final loadedAssessment = assessmentProvider.assessment!;
      final isActuallyPreAssessment = assessmentProvider.isPreAssessment;

      print('[ReadingComprehensionWrapper] Loaded assessment type: ${loadedAssessment.type}');
      print('[ReadingComprehensionWrapper] Provider isPreAssessment: $isActuallyPreAssessment');
      print('[ReadingComprehensionWrapper] Expected isPreAssessment: ${widget.isPreAssessment}');

      // CRITICAL: Verify we have the correct assessment type
      if (!widget.isPreAssessment && isActuallyPreAssessment) {
        print('[ReadingComprehensionWrapper] ERROR: Expected main assessment but got pre-assessment');
        _handleError('Could not load main assessment - only pre-assessment data available');
        return;
      }

      if (loadedAssessment.questions.isEmpty) {
        print('[ReadingComprehensionWrapper] No questions in loaded assessment');
        _handleError('No assessment questions found');
        return;
      }

      // Find Reading Comprehension questions based on assessment type
      List<Question> rcQuestions;
      if (widget.isPreAssessment) {
        // For pre-assessment: Look for various RC patterns
        rcQuestions = loadedAssessment.questions.where((q) =>
          q.questionTypeId == 'reading_comprehension' ||
          q.questionId.contains('RC') ||
          q.questionId.startsWith('PRE_RC') ||
          (q.passages != null && q.passages!.isNotEmpty) ||
          (q.sentenceQuestions != null && q.sentenceQuestions!.isNotEmpty)
        ).toList();
      } else {
        // For main assessment: Look for RC_ pattern
        rcQuestions = loadedAssessment.questions.where((q) =>
          q.questionId.startsWith('RC_') ||
          q.questionTypeId == 'reading_comprehension'
        ).toList();
      }

      print('[ReadingComprehensionWrapper] Found ${rcQuestions.length} RC questions');
      for (var q in rcQuestions) {
        print('[ReadingComprehensionWrapper] RC Question: ${q.questionId}');
      }

      if (rcQuestions.isEmpty) {
        print('[ReadingComprehensionWrapper] No RC questions found in assessment');
        _handleError('No reading comprehension questions found');
        return;
      }

      // Sort RC questions by questionId
      rcQuestions.sort((a, b) {
        if (widget.isPreAssessment) {
          // For pre-assessment, maintain original order or sort by ID
          return a.questionId.compareTo(b.questionId);
        } else {
          // For main assessment, sort by RC_ number
          final aNum = int.tryParse(a.questionId.substring(3)) ?? 0;
          final bNum = int.tryParse(b.questionId.substring(3)) ?? 0;
          return aNum.compareTo(bNum);
        }
      });

      final firstRcQuestion = rcQuestions.first;
      print('[ReadingComprehensionWrapper] Using first RC question: ${firstRcQuestion.questionId}');

      // Navigate to ReadingComprehensionScreen with the first question
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider.value(
              value: assessmentProvider,
              child: ReadingComprehensionScreen(
                question: firstRcQuestion,
                assessmentType: widget.isPreAssessment ? 'pre_assessment' : 'main_assessment',
                onComplete: () {
                  if (widget.onComplete != null) {
                    widget.onComplete!();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                onAnswerSubmitted: (String answer) {
                  print('[ReadingComprehensionWrapper] Answer submitted: $answer');
                },
                handleAllRcQuestions: true, // Handle all RC questions
                rcQuestionsList: rcQuestions, // Pass all RC questions
              ),
            ),
          ),
        );
      }
    } catch (e) {
      print('[ReadingComprehensionWrapper] Error loading assessment: $e');
      _handleError('Failed to load assessment: $e');
    }
  }

  void _handleError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1C2B4E),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFDE37C),
        ),
      ),
    );
  }
}
