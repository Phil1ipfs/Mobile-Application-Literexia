// lib/config/router.dart
import 'package:flutter/material.dart';
import 'package:literexia/screens/profile_screen.dart';
import '../screens/splash_screen.dart';

// ─── CORE SCREENS ─────────────────────────────────────────────────────────────
import 'package:literexia/screens/home_screen.dart';
import 'package:literexia/screens/login_screen.dart'; // Added login screen


// ─── ASSESSMENT FLOW ──────────────────────────────────────────────────────────
import '../features/assessments/ui/pre_assessment_screen.dart';
import '../features/assessments/ui/pre_assessment_question_screen.dart';
import '../features/assessments/ui/pre_assessment_result_screen.dart';
import '../features/assessments/ui/pre_assessment_intro_screen.dart';

class AppRouter {
  // ─── CORE ROUTES ────────────────────────────────────────────────────────────
  static const String splash = '/';
  static const String login = '/login'; // Added login route
  static const String home = '/home';
  static const String lesson = '/lesson';
  static const String userManagement = '/user-management';
  static const String assessment = '/assesssment';
  static const String profile = '/profile';

  // ─── ASSESSMENT ROUTES ────────────────────────────────────────────────────────
  static const String preAssessment = '/pre-assessment';
  static const String preAssessmentQuestion = '/pre-assessment-question';
  static const String preAssessmentResult = '/pre-assessment-result';
  static const String preAssessmentIntro = '/pre-assessment-intro'; 
  // Add spl
  // static const String splash = '/splash';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ─── CORE ────────────────────────────────────────────────────────────────
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      
      case preAssessment:
        return MaterialPageRoute(builder: (_) => const PreAssessmentScreen());
      
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      
      case preAssessmentIntro:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => PreAssessmentIntroScreen(
            assessmentId: args['assessmentId'] ?? 1,
          ),
        );
      
      case preAssessmentQuestion:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => PreAssessmentQuestionScreen(
            assessmentId: args['assessmentId'] ?? 1,
            provider: args['provider'],
            onAssessmentComplete: args['onComplete'],
          ),
        );

      case preAssessmentResult:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => PreAssessmentResultScreen(
            readingLevel: args['readingLevel'] ?? 'Undefined',
            score: args['score'] ?? 0,
            totalQuestions: args['totalQuestions'] ?? 5,
          ),
        );

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      // case dbTest:
      //   return MaterialPageRoute(builder: (_) => const DbTestScreen());
      // case lesson:
      //   final args = settings.arguments as Map<String, dynamic>? ?? {};
      //   return MaterialPageRoute(
      //     builder: (_) => LessonScreen(
      //       lessonNumber: args['lessonNumber'] as int,
      //       lessonTitle: args['lessonTitle'] as String,
      //     ),
      //   );
      // case profile:
      //   return MaterialPageRoute(builder: (_) => const ProfileScreen());
      // case settingss:
      //   return MaterialPageRoute(
      //       builder: (_) => const CustomizationSettingsScreen());

      // case penguinFeeling:
      //   return MaterialPageRoute(builder: (_) => const PenguinFeelingScreen());
      // case themeSelection:
      //   return MaterialPageRoute(builder: (_) => const ThemeSelectionScreen());

      // // ─── ASSESSMENT ──────────────────────────────────────────────────────────
      // case welcome:
      //   return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      // case preAssessment:
      //   return MaterialPageRoute(builder: (_) => const PreAssessmentScreen());
      // case preAssessmentQuestions:
      //   return PageRouteBuilder(
      //     pageBuilder: (c, a, sa) => const PreAssessmentQuestionScreen(),
      //     transitionsBuilder: (c, a, sa, child) {
      //       final tween = Tween(begin: const Offset(1, 0), end: Offset.zero)
      //           .chain(CurveTween(curve: Curves.ease));
      //       return SlideTransition(position: a.drive(tween), child: child);
      //     },
      //   );
      // case assessmentAnalyzing:
      //   return MaterialPageRoute(
      //       builder: (_) => const AssessmentAnalyzingScreen());
      // case assessmentResults:
      //   return MaterialPageRoute(
      //       builder: (_) => const AssessmentResultsScreen());

      // ─── FALLBACK ────────────────────────────────────────────────────────────
      default:
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
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
