// lib/features/auth/logic/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart' show modify, where;
import '../../../models/user_model.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/database_service.dart';

enum AuthStatus {
  initial,
  authenticating,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider with ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  User? _currentUser;
  final UserRepository _userRepository = UserRepository();
  final DatabaseService _databaseService = DatabaseService();

  // Getters
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  List<dynamic> getCompletedLessons() {
    return _currentUser?.completedLessons ?? [];
  }

  // Add method to check if specific lesson is completed
  bool isLessonCompleted(int lessonIndex) {
    final completedLessons = getCompletedLessons();
    return completedLessons.contains(lessonIndex) || 
           completedLessons.contains(lessonIndex.toString());
  }

  // Initialize auth state
  Future<void> initialize() async {
    try {
      print('Initializing auth provider...');
      // Initialize database connection
      final dbInitialized = await _databaseService.initialize();
      print('Database initialized: $dbInitialized');

      if (!dbInitialized) {
        _status = AuthStatus.error;
        _errorMessage = 'Database connection failed';
        notifyListeners();
        return;
      }

      // Check for saved authentication state
      await _restoreAuthenticationState();
    } catch (e) {
      print('Error initializing auth provider: $e');
      _status = AuthStatus.error;
      _errorMessage = 'Failed to initialize authentication: $e';
      notifyListeners();
    }
  }

  // Restore authentication state from local storage
  Future<void> _restoreAuthenticationState() async {
    try {
      print('[AuthProvider] Attempting to restore authentication state...');

      // Check if there's a currently saved session
      final savedSession = await _getSavedSession();

      if (savedSession != null && savedSession.isNotEmpty) {
        final idNumber = savedSession['idNumber'] as String?;

        if (idNumber != null && idNumber.isNotEmpty) {
          print('[AuthProvider] Found saved session for ID: $idNumber');

          // Try to get user data from local database first
          Map<String, dynamic>? userData = await _databaseService.getUserFromLocalDb(idNumber);

          if (userData != null) {
            // Restore user from local data
            _currentUser = User(
              idNumber: idNumber,
              name: userData['name'] as String?,
              readingLevel: userData['readingLevel'] as String?,
              preAssessmentCompleted: (userData['preAssessmentCompleted'] as int?) == 1,
              completedLessons: _parseCompletedLessons(userData['completedLessons']),
              readingPercentage: userData['readingPercentage'] as double?,
            );

            _status = AuthStatus.authenticated;
            print('[AuthProvider] Successfully restored user session: ${_currentUser?.name}');
            notifyListeners();
            return;
          }
        }
      }

      // No saved session found or restoration failed
      print('[AuthProvider] No saved session found or restoration failed');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      print('[AuthProvider] Error restoring authentication state: $e');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // Helper method to parse completed lessons from various formats
  List<int>? _parseCompletedLessons(dynamic completedLessons) {
    if (completedLessons == null) return null;

    if (completedLessons is String && completedLessons.isNotEmpty) {
      try {
        // Try to parse JSON array string
        final parsed = completedLessons.split(',')
            .map((e) => int.tryParse(e.trim()))
            .where((e) => e != null)
            .cast<int>()
            .toList();
        return parsed.isEmpty ? null : parsed;
      } catch (e) {
        print('[AuthProvider] Error parsing completed lessons string: $e');
        return null;
      }
    }

    if (completedLessons is List) {
      return completedLessons.map((e) => int.tryParse(e.toString())).where((e) => e != null).cast<int>().toList();
    }

    return null;
  }

  // Get saved session data
  Future<Map<String, dynamic>?> _getSavedSession() async {
    try {
      // Check local database for the most recent user session
      // Since we don't have a "current_session" table, we'll look for the most recently active user
      final allUsers = await _databaseService.getAllLocalUsers();

      if (allUsers.isNotEmpty) {
        // For now, return the first user found (in a real app, you'd have a "last_active" field)
        // This is a simple implementation - you might want to add a timestamp field
        return allUsers.first;
      }

      return null;
    } catch (e) {
      print('[AuthProvider] Error getting saved session: $e');
      return null;
    }
  }

  // Save current session
  Future<void> _saveSession() async {
    if (_currentUser == null) return;

    try {
      // Save the current user data to local database
      await _databaseService.saveUserDataLocally(
        idNumber: _currentUser!.idNumber,
        name: _currentUser!.name,
        readingLevel: _currentUser!.readingLevel,
        readingPercentage: _currentUser!.readingPercentage,
        preAssessmentCompleted: _currentUser!.preAssessmentCompleted,
      );

      print('[AuthProvider] Session saved for user: ${_currentUser!.idNumber}');
    } catch (e) {
      print('[AuthProvider] Error saving session: $e');
    }
  }

  // Login with ID number
  Future<bool> login(String idNumber) async {
    try {
      print('Attempting login with ID: $idNumber');
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      // Validate ID number format
      int? numericId;
      try {
        numericId = int.parse(idNumber);
        print('Parsed ID number to integer: $numericId');
      } catch (e) {
        print('ID number is not a valid integer: $idNumber');
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'ID number must be a valid number.';
        notifyListeners();
        return false;
      }

      // Special case for user 30145 - always direct to pre-assessment
      if (idNumber == '30145') {
        print('Test user 30145 detected - directing to pre-assessment');
        
        // Create a minimal user for testing WITHOUT a reading level
        _currentUser = User(
          idNumber: '30145',
          name: 'Maria L. Santos',
          readingLevel: null, // Always null to force pre-assessment
          firstName: 'Maria',
          lastName: 'Santos',
          middleName: 'L.',
          age: 8,
          preAssessmentCompleted: false, // Mark as not completed
        );
        
        // Save this user to local database with null reading level
        try {
          await _databaseService.saveUserDataLocally(
            idNumber: '30145',
            name: 'Maria L. Santos',
            readingLevel: null, // Always null to force pre-assessment
            readingPercentage: null,
            preAssessmentCompleted: false,
          );
        } catch (e) {
          print('Error saving test user to local DB: $e');
        }

        // Save the current session
        await _saveSession();

        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }

      // For all other users, proceed with normal authentication flow
      // First try to verify via repository (MongoDB)
      print('Attempting MongoDB authentication');
      bool isValid = false;
      
      try {
        isValid = await _userRepository.verifyLogin(idNumber);
        print('MongoDB login verification result: $isValid');
      } catch (e) {
        print('Error during MongoDB verification: $e');
        // Continue to local authentication
      }

      if (isValid) {
        // Get user details from MongoDB
        User? user;
        try {
          user = await _userRepository.getUserByIdNumber(idNumber);
          print('Retrieved user from MongoDB: ${user?.name}');
        } catch (e) {
          print('Error retrieving user from MongoDB: $e');
          // Continue to try local authentication
        }
        
        if (user != null) {
          _currentUser = user;

          // Save to local DB for offline login and sync completion data
          try {
            await _databaseService.saveUserDataLocally(
              idNumber: idNumber,
              name: _currentUser?.name,
              readingLevel: _currentUser?.readingLevel,
              readingPercentage: _currentUser?.readingPercentage,
              preAssessmentCompleted: _currentUser?.preAssessmentCompleted,
              syncCompletionData: true, // Enable completion data sync
            );
            print('[AuthProvider] User data saved locally with completion sync');
          } catch (e) {
            print('Error saving to local DB: $e');
            // Not critical, continue
          }

          // Save the current session
          await _saveSession();

          _status = AuthStatus.authenticated;
          notifyListeners();
          return true;
        }
      }
      
      // If MongoDB login failed, try local database
      print('MongoDB login failed, trying local database');
      Map<String, dynamic>? localUser;
      
      try {
        localUser = await _databaseService.getUserFromLocalDb(idNumber);
      } catch (e) {
        print('Error accessing local DB: $e');
        // Continue to hardcoded fallback
      }
      
      if (localUser != null) {
        print('Found user in local database: $localUser');
        
        // Create a User object from local data
        try {
          _currentUser = User(
            idNumber: idNumber,
            name: localUser['name'] as String?,
            readingLevel: localUser['readingLevel'] as String?,
            preAssessmentCompleted: (localUser['preAssessmentCompleted'] as int?) == 1,
            completedLessons: _parseCompletedLessons(localUser['completedLessons']),
            readingPercentage: localUser['readingPercentage'] as double?,
          );

          print('Created user from local data: ${_currentUser?.name}');

          // Save the current session
          await _saveSession();

          _status = AuthStatus.authenticated;
          notifyListeners();

          // Return success for local authentication
          return true;
        } catch (e) {
          print('Error creating user from local data: $e');
          // Continue to hardcoded fallback
        }
      }

      // If we get here, authentication failed
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Invalid ID number. Please check with your administrator.';
      notifyListeners();
      return false;
    } catch (e) {
      print('Login error: $e');
      _status = AuthStatus.error;
      _errorMessage = 'Login error: $e';
      notifyListeners();
      return false;
    }
  }

  // Update completed lessons
  Future<bool> updateCompletedLesson(int lessonNumber) async {
    if (_currentUser == null) return false;

    try {
      final success = await _userRepository.updateCompletedLesson(
        _currentUser!.idNumber,
        lessonNumber,
      );

      if (success) {
        // Update local user object with the new completed lesson
        final updatedLessons = List<int>.from(
          _currentUser!.completedLessons ?? [],
        );
        if (!updatedLessons.contains(lessonNumber)) {
          updatedLessons.add(lessonNumber);
        }

        _currentUser = _currentUser!.copyWith(completedLessons: updatedLessons);
        notifyListeners();
      }

      return success;
    } catch (e) {
      print('Error updating completed lesson: $e');
      return false;
    }
  }
  
  // Logout
  Future<void> logout() async {
    // Clear local database to prevent data bleeding between accounts
    try {
      await _databaseService.clearLocalUserData();
      print('[AuthProvider] Local user data cleared on logout');
    } catch (e) {
      print('[AuthProvider] Error clearing local user data on logout: $e');
    }
    
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
  
  // Method to update user reading level
  Future<void> updateUserReadingLevel(String readingLevel) async {
    if (_currentUser != null) {
      // Create a new user model with updated reading level
      final updatedUser = _currentUser!.copyWith(readingLevel: readingLevel);

      // Update the current user
      _currentUser = updatedUser;

      print('[AuthProvider] Updated user reading level in memory: $readingLevel');

      // Update the database
      try {
        final databaseService = DatabaseService();
        final success = await databaseService.updateUserPreAssessmentCompletion(
          _currentUser!.idNumber.toString(),
          readingLevel,
          null, // readingPercentage - not needed for level updates
        );
        
        if (success) {
          print('[AuthProvider] Successfully updated reading level in database: $readingLevel');
        } else {
          print('[AuthProvider] Failed to update reading level in database: $readingLevel');
        }
      } catch (e) {
        print('[AuthProvider] Error updating reading level in database: $e');
      }

      // Save the updated session
      await _saveSession();

      notifyListeners();
    }
  }

  // Update pre-assessment completion status in memory
  void setPreAssessmentCompleted(bool completed) {
    if (_currentUser != null) {
      // Create a new user model with updated pre-assessment completion status
      final updatedUser = _currentUser!.copyWith(preAssessmentCompleted: completed);

      // Update the current user
      _currentUser = updatedUser;

      print('[AuthProvider] Updated user pre-assessment completion status: $completed');

      // Save the updated session
      _saveSession();

      notifyListeners();
    }
  }

  void updateReadingPercentage(double percentage) {
    if (_currentUser != null) {
      // Create a new user model with updated reading percentage
      final updatedUser = _currentUser!.copyWith(readingPercentage: percentage);

      // Update the current user
      _currentUser = updatedUser;

      print('[AuthProvider] Updated user reading percentage in memory: $percentage%');

      // Save the updated session
      _saveSession();

      notifyListeners();
    }
  }

  // Add method to track completed lessons
  void addCompletedLesson(int lessonIndex) {
    if (_currentUser != null) {
      _currentUser!.completedLessons ??= [];
      if (!_currentUser!.completedLessons!.contains(lessonIndex) &&
          !_currentUser!.completedLessons!.contains(lessonIndex.toString())) {
        _currentUser!.completedLessons!.add(lessonIndex);

        print('[AuthProvider] Added completed lesson: $lessonIndex');

        // Save the updated session
        _saveSession();

        notifyListeners();
      }
    }
  }
}

