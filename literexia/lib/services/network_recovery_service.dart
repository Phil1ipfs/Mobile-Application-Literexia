// lib/services/network_recovery_service.dart
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../config/timeout_config.dart';

/// Network Recovery Service for handling timeout scenarios
///
/// This service provides automatic recovery mechanisms for network
/// timeouts and connection issues, with user-friendly feedback.
class NetworkRecoveryService extends ChangeNotifier {
  static final NetworkRecoveryService _instance = NetworkRecoveryService._internal();
  factory NetworkRecoveryService() => _instance;
  NetworkRecoveryService._internal();

  // Connection state
  bool _isConnected = true;
  bool _isRecovering = false;
  String? _lastError;
  DateTime? _lastFailureTime;
  int _consecutiveFailures = 0;

  // Recovery settings
  static const int maxConsecutiveFailures = 3;
  static const Duration recoveryCheckInterval = Duration(seconds: 30);
  static const Duration backoffDuration = Duration(minutes: 1);

  // Connectivity monitoring
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _recoveryTimer;

  // Getters
  bool get isConnected => _isConnected;
  bool get isRecovering => _isRecovering;
  String? get lastError => _lastError;
  bool get isInBackoffPeriod {
    if (_lastFailureTime == null) return false;
    return DateTime.now().difference(_lastFailureTime!) < backoffDuration;
  }

  /// Initialize the network recovery service
  Future<void> initialize() async {
    print('[NetworkRecovery] Initializing network recovery service');

    // Start monitoring connectivity
    _startConnectivityMonitoring();

    // Perform initial network check
    await _checkNetworkStatus();
  }

  /// Start monitoring network connectivity changes
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) async {
        print('[NetworkRecovery] Connectivity changed: $result');

        if (result == ConnectivityResult.none) {
          _handleNetworkLoss();
        } else {
          await _handleNetworkRestoration();
        }
      },
    );
  }

  /// Handle network connection loss
  void _handleNetworkLoss() {
    print('[NetworkRecovery] Network connection lost');

    _isConnected = false;
    _lastError = 'Network connection lost';
    _lastFailureTime = DateTime.now();
    _consecutiveFailures++;

    notifyListeners();

    // Start recovery attempts
    _startRecoveryProcess();
  }

  /// Handle network connection restoration
  Future<void> _handleNetworkRestoration() async {
    print('[NetworkRecovery] Network connectivity restored, verifying...');

    // Verify actual internet connectivity
    final hasInternet = await _testInternetConnectivity();

    if (hasInternet) {
      print('[NetworkRecovery] Internet connectivity confirmed');
      _handleSuccessfulRecovery();
    } else {
      print('[NetworkRecovery] No internet access despite connectivity');
      _handleNetworkLoss();
    }
  }

  /// Test actual internet connectivity
  Future<bool> _testInternetConnectivity() async {
    try {
      final client = HttpClient();
      TimeoutConfig.configureHttpClient(client, timeout: TimeoutConfig.quick);

      return await TimeoutConfig.withTimeout(
        _performConnectivityTest(client),
        timeout: TimeoutConfig.quick,
        operationName: 'Internet Connectivity Test',
      );
    } catch (e) {
      print('[NetworkRecovery] Internet connectivity test failed: $e');
      return false;
    }
  }

  Future<bool> _performConnectivityTest(HttpClient client) async {
    try {
      final request = await client.getUrl(Uri.parse('https://www.google.com'));
      final response = await request.close();

      final hasConnection = response.statusCode >= 200 && response.statusCode < 500;
      print('[NetworkRecovery] Connectivity test result: $hasConnection (${response.statusCode})');

      return hasConnection;
    } finally {
      client.close();
    }
  }

  /// Start the recovery process
  void _startRecoveryProcess() {
    if (_isRecovering) return; // Already recovering

    print('[NetworkRecovery] Starting recovery process');
    _isRecovering = true;
    notifyListeners();

    // Don't attempt recovery if in backoff period
    if (isInBackoffPeriod) {
      print('[NetworkRecovery] In backoff period, delaying recovery');
      return;
    }

    _scheduleRecoveryCheck();
  }

  /// Schedule periodic recovery checks
  void _scheduleRecoveryCheck() {
    _recoveryTimer?.cancel();

    _recoveryTimer = Timer.periodic(recoveryCheckInterval, (timer) async {
      if (!_isRecovering) {
        timer.cancel();
        return;
      }

      print('[NetworkRecovery] Performing recovery check...');
      await _attemptRecovery();
    });
  }

  /// Attempt to recover network connection
  Future<void> _attemptRecovery() async {
    try {
      // Check if we're still in a failure state
      if (_consecutiveFailures >= maxConsecutiveFailures && isInBackoffPeriod) {
        print('[NetworkRecovery] Too many failures, waiting in backoff period');
        return;
      }

      // Test connectivity
      final hasConnection = await _testInternetConnectivity();

      if (hasConnection) {
        _handleSuccessfulRecovery();
      } else {
        _handleFailedRecovery();
      }
    } catch (e) {
      print('[NetworkRecovery] Recovery attempt failed: $e');
      _handleFailedRecovery();
    }
  }

  /// Handle successful network recovery
  void _handleSuccessfulRecovery() {
    print('[NetworkRecovery] Network recovery successful');

    _isConnected = true;
    _isRecovering = false;
    _lastError = null;
    _consecutiveFailures = 0;
    _lastFailureTime = null;

    _recoveryTimer?.cancel();
    notifyListeners();
  }

  /// Handle failed recovery attempt
  void _handleFailedRecovery() {
    print('[NetworkRecovery] Recovery attempt failed');

    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();
    _lastError = 'Recovery attempt failed';

    if (_consecutiveFailures >= maxConsecutiveFailures) {
      print('[NetworkRecovery] Max failures reached, entering backoff period');
      _isRecovering = false;
      _recoveryTimer?.cancel();

      // Schedule recovery restart after backoff period
      Timer(backoffDuration, () {
        if (!_isConnected) {
          print('[NetworkRecovery] Backoff period ended, restarting recovery');
          _startRecoveryProcess();
        }
      });
    }

    notifyListeners();
  }

  /// Check current network status
  Future<void> _checkNetworkStatus() async {
    try {
      final hasConnection = await _testInternetConnectivity();

      if (hasConnection != _isConnected) {
        if (hasConnection) {
          _handleSuccessfulRecovery();
        } else {
          _handleNetworkLoss();
        }
      }
    } catch (e) {
      print('[NetworkRecovery] Network status check failed: $e');
      if (_isConnected) {
        _handleNetworkLoss();
      }
    }
  }

  /// Force a network recovery attempt
  Future<void> forceRecovery() async {
    print('[NetworkRecovery] Forcing recovery attempt');

    _consecutiveFailures = 0; // Reset failure count
    _lastFailureTime = null;  // Clear backoff period

    await _attemptRecovery();
  }

  /// Get recovery status message
  String getRecoveryStatusMessage() {
    if (_isConnected) {
      return 'Network connection is stable';
    }

    if (_isRecovering) {
      return 'Attempting to restore network connection...';
    }

    if (isInBackoffPeriod) {
      final remaining = backoffDuration - DateTime.now().difference(_lastFailureTime!);
      return 'Connection recovery paused. Retrying in ${remaining.inMinutes} minutes.';
    }

    return _lastError ?? 'Network connection lost';
  }

  /// Get user-friendly timeout recovery instructions
  String getTimeoutRecoveryInstructions() {
    if (!_isConnected) {
      return 'Please check your internet connection and try again.';
    }

    return 'Operation timed out. This may be due to slow internet connection. Please wait and try again.';
  }

  /// Handle timeout error with recovery context
  Future<void> handleTimeoutError({
    required String operation,
    required dynamic error,
    VoidCallback? onRecoveryStarted,
    VoidCallback? onRecoveryCompleted,
  }) async {
    print('[NetworkRecovery] Handling timeout error for: $operation');
    print('[NetworkRecovery] Error: $error');

    // Record the failure
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();
    _lastError = 'Timeout in $operation';

    // Check if this is a network-related timeout
    if (TimeoutConfig.isRetryableError(error)) {
      print('[NetworkRecovery] Timeout appears to be network-related');

      // Test current connectivity
      final hasConnection = await _testInternetConnectivity();

      if (!hasConnection) {
        print('[NetworkRecovery] No internet connection detected');
        _handleNetworkLoss();
        if (onRecoveryStarted != null) onRecoveryStarted();
      } else {
        print('[NetworkRecovery] Internet connection available, timeout may be due to slow connection');
      }
    }

    notifyListeners();
  }

  /// Dispose of resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _recoveryTimer?.cancel();
    super.dispose();
  }
}

/// Extension for Future to add automatic timeout recovery
extension TimeoutRecovery<T> on Future<T> {
  /// Wrap future with automatic timeout recovery handling
  Future<T> withRecovery({
    Duration? timeout,
    required String operationName,
    VoidCallback? onRecoveryStarted,
    VoidCallback? onRecoveryCompleted,
  }) async {
    final recoveryService = NetworkRecoveryService();

    try {
      return await TimeoutConfig.withTimeout(
        this,
        timeout: timeout,
        operationName: operationName,
      );
    } catch (e) {
      // Handle timeout with recovery
      await recoveryService.handleTimeoutError(
        operation: operationName,
        error: e,
        onRecoveryStarted: onRecoveryStarted,
        onRecoveryCompleted: onRecoveryCompleted,
      );
      rethrow;
    }
  }
}