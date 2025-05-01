// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'config/router.dart';
import 'core/theme/app_theme.dart';

import 'features/auth/logic/auth_provider.dart';
import 'features/lessons/logic/aralin/aralin_provider.dart';

import 'services/database_service.dart';
import 'utils/mongo_debug.dart'; // Import the debug utility

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

    // Debug the MongoDB URI
    MongoDebug.checkMongoURI();

    // Test encoding functions
    MongoDebug.testEncodingFunctions();
  } catch (e) {
    print('Failed to load environment variables: $e');
  }

  // Force real connection for testing (only in development)
  DatabaseService.forceRealConnection =
      !kIsWeb; // Default to mock for web, real for mobile
  print(
    'MongoDB real connection forced: ${DatabaseService.forceRealConnection}',
  );

  // Initialize MongoDB connection
  final dbService = DatabaseService();
  bool dbInitialized = await dbService.initialize();

  if (dbInitialized) {
    print('MongoDB connection initialized successfully');

    // IMPORTANT: Ensure test user exists in database
    bool userCreated = await dbService.ensureTestUserExists();
    print('Test user created/verified: $userCreated');

    // Test the connection to verify it's working
    bool connectionTest = await dbService.testConnection();
    print('MongoDB connection test: ${connectionTest ? 'PASSED' : 'FAILED'}');

    if (!connectionTest) {
      print('Connection Error: ${dbService.connectionError}');
    }
  } else {
    print('Failed to initialize MongoDB: ${dbService.connectionError}');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provide DatabaseService globally - it's already a singleton
        Provider<DatabaseService>.value(value: DatabaseService()),

        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AralinProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Literexia',
            theme: AppTheme.lightTheme,
            initialRoute:
                authProvider.isAuthenticated ? AppRouter.home : AppRouter.login,
            onGenerateRoute: AppRouter.generateRoute,
          );
        },
      ),
    );
  }
}
