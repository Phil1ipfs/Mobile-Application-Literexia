// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:literexia/features/intervention/logic/intervention_provider.dart';
import 'package:literexia/features/settings/provider/settings_provider.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart'; // PlayAI TTS provider import
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'config/router.dart';
import 'core/theme/app_theme.dart';

import 'features/auth/logic/auth_provider.dart';
import 'features/lessons/logic/aralin/aralin_provider.dart';
import 'features/assessments/logic/assessment_provider.dart';

import 'services/database_service.dart';
import 'utils/mongo_debug.dart'; // Import the debug utility

// Define navigatorKey at the top level so it's accessible throughout the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set orientation to portrait only
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Print platform information for debugging
  MongoDebug.printPlatformInfo();

  // Load environment variables for MongoDB connection
  try {
    await dotenv.load(fileName: ".env");
    print('Loaded environment variables: ${dotenv.env.keys.join(', ')}');

    MongoDebug.checkMongoURI();
    MongoDebug.testEncodingFunctions();
  } catch (e) {
    print('Failed to load environment variables: $e');
  }

  DatabaseService.forceRealConnection = !kIsWeb;
  print(
    'MongoDB real connection forced: ${DatabaseService.forceRealConnection}',
  );

  // Initialize MongoDB connection
  final dbService = DatabaseService();
  bool dbInitialized = await dbService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: DatabaseService()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AralinProvider()),
        ChangeNotifierProvider(create: (_) => AssessmentProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => InterventionProvider()),
        ChangeNotifierProvider(
          create: (context) {
            final ttsProvider = TTSProvider();
            // Initialize PlayAI TTS provider after creation
            Future.microtask(() async {
              await ttsProvider.initialize();
              print(
                  '[Main] PlayAI TTS Provider initialized - Available: ${ttsProvider.isAvailable}');

              // Get theme provider and connect TTS only once after initialization
              final themeProvider =
                  Provider.of<ThemeProvider>(context, listen: false);
              themeProvider.setTTSProvider(ttsProvider);

              // Enable TTS by default
              ttsProvider.setEnabled(true);
            });
            return ttsProvider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'Literexia',
              theme: themeProvider.getThemeData(),
              initialRoute: AppRouter.splash,
              onGenerateRoute: AppRouter.generateRoute,
              builder: (context, child) {
                // Preload all fonts
                for (final font in themeProvider.availableFonts) {
                  final textStyle = TextStyle(fontFamily: font);
                  precacheImage(
                    NetworkImage('https://via.placeholder.com/1x1'),
                    context,
                    onError: (e, stackTrace) {},
                  );
                  // Force font loading
                  Text('', style: textStyle);
                }
                return child!;
              });
        },
      ),
    );
  }
}
