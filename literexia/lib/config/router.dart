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
