// lib/features/auth/logic/auth_provider.dart
import 'package:flutter/foundation.dart';
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

      // For demo purposes, we'll set status to unauthenticated
      // In a real app, you would check local storage for saved credentials
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      print('Error initializing auth provider: $e');
      _status = AuthStatus.error;
      _errorMessage = 'Failed to initialize authentication: $e';
      notifyListeners();
    }
  }

  // Login with ID number - Now handles integer IDs properly
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

      // Verify login (the repository now handles integer conversion)
      final isValid = await _userRepository.verifyLogin(idNumber);
      print('Login verification result: $isValid');

      if (isValid) {
        // Get user details
        _currentUser = await _userRepository.getUserByIdNumber(idNumber);
        print('Retrieved user: ${_currentUser?.name}');

        if (_currentUser == null) {
          // This shouldn't happen if verifyLogin was successful
          print(
            'WARNING: verifyLogin succeeded but getUserByIdNumber returned null',
          );
          _status = AuthStatus.error;
          _errorMessage = 'Error retrieving user data';
          notifyListeners();
          return false;
        }

        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.unauthenticated;
        _errorMessage =
            'Invalid ID number. Please check with your administrator.';
        notifyListeners();
        return false;
      }
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
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
  
  // Method to update user reading level
  void updateUserReadingLevel(String readingLevel) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(readingLevel: readingLevel);
      notifyListeners();
    }
  }
}