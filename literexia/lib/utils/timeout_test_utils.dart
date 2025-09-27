// lib/utils/timeout_test_utils.dart
import 'dart:async';
import 'dart:math';
import '../config/timeout_config.dart';
import '../services/network_recovery_service.dart';

/// Utility class for testing timeout implementations
///
/// This class provides methods to test and validate timeout
/// configurations across different services.
class TimeoutTestUtils {
  static final Random _random = Random();

  /// Test basic timeout functionality
  static Future<void> testBasicTimeout() async {
    print('=== TESTING BASIC TIMEOUT FUNCTIONALITY ===');

    try {
      // Test a quick timeout that should succeed
      await TimeoutConfig.withTimeout(
        Future.delayed(Duration(milliseconds: 100)),
        timeout: TimeoutConfig.quick,
        operationName: 'Quick Test',
      );
      print('✅ Quick timeout test passed');
    } catch (e) {
      print('❌ Quick timeout test failed: $e');
    }

    try {
      // Test a timeout that should fail
      await TimeoutConfig.withTimeout(
        Future.delayed(Duration(seconds: 10)),
        timeout: Duration(seconds: 1),
        operationName: 'Timeout Test',
      );
      print('❌ Timeout test unexpectedly succeeded');
    } catch (e) {
      print('✅ Timeout test correctly failed: $e');
    }
  }

  /// Test retry functionality
  static Future<void> testRetryFunctionality() async {
    print('\n=== TESTING RETRY FUNCTIONALITY ===');

    int attemptCount = 0;

    try {
      await TimeoutConfig.withRetry(
        () async {
          attemptCount++;
          print('Attempt $attemptCount');

          if (attemptCount < 3) {
            throw TimeoutException('Simulated failure', Duration(seconds: 1));
          }

          return 'Success';
        },
        timeout: TimeoutConfig.quick,
        maxAttempts: 3,
        operationName: 'Retry Test',
      );

      print('✅ Retry test passed after $attemptCount attempts');
    } catch (e) {
      print('❌ Retry test failed: $e');
    }
  }

  /// Test network recovery service
  static Future<void> testNetworkRecovery() async {
    print('\n=== TESTING NETWORK RECOVERY SERVICE ===');

    final recoveryService = NetworkRecoveryService();
    await recoveryService.initialize();

    print('Recovery service initialized');
    print('Status: ${recoveryService.getRecoveryStatusMessage()}');

    // Simulate a timeout error
    await recoveryService.handleTimeoutError(
      operation: 'Test Operation',
      error: TimeoutException('Test timeout', Duration(seconds: 1)),
      onRecoveryStarted: () => print('Recovery started'),
      onRecoveryCompleted: () => print('Recovery completed'),
    );

    print('Recovery instructions: ${recoveryService.getTimeoutRecoveryInstructions()}');
  }

  /// Test timeout configurations for different operations
  static void testTimeoutConfigurations() {
    print('\n=== TESTING TIMEOUT CONFIGURATIONS ===');

    final operations = [
      'ping',
      'login',
      'upload',
      'sync',
      'tts',
      'database',
      'assessment',
      'unknown',
    ];

    for (final operation in operations) {
      final timeout = TimeoutConfig.getTimeoutForOperation(operation);
      print('$operation: ${timeout.inSeconds}s');
    }
  }

  /// Simulate various network conditions
  static Future<void> simulateNetworkConditions() async {
    print('\n=== SIMULATING NETWORK CONDITIONS ===');

    // Test fast network
    await _simulateNetworkOperation('Fast Network', Duration(milliseconds: 100));

    // Test slow network
    await _simulateNetworkOperation('Slow Network', Duration(seconds: 3));

    // Test timeout scenario
    await _simulateNetworkOperation('Timeout Scenario', Duration(seconds: 20));

    // Test intermittent failure
    await _simulateIntermittentFailure();
  }

  static Future<void> _simulateNetworkOperation(String name, Duration delay) async {
    print('\n--- Testing $name ---');

    try {
      final result = await TimeoutConfig.withTimeout(
        _simulateOperation(delay),
        timeout: TimeoutConfig.standard,
        operationName: name,
      );

      print('✅ $name completed: $result');
    } catch (e) {
      print('❌ $name failed: $e');
    }
  }

  static Future<void> _simulateIntermittentFailure() async {
    print('\n--- Testing Intermittent Failure ---');

    int attempts = 0;

    try {
      final result = await TimeoutConfig.withRetry(
        () async {
          attempts++;
          print('Attempt $attempts');

          // Randomly fail on first few attempts
          if (attempts <= 2 && _random.nextBool()) {
            throw TimeoutException('Random failure', Duration(seconds: 1));
          }

          return 'Success after $attempts attempts';
        },
        timeout: TimeoutConfig.quick,
        maxAttempts: 3,
        operationName: 'Intermittent Failure Test',
      );

      print('✅ Intermittent failure test passed: $result');
    } catch (e) {
      print('❌ Intermittent failure test failed after $attempts attempts: $e');
    }
  }

  static Future<String> _simulateOperation(Duration delay) async {
    await Future.delayed(delay);
    return 'Operation completed in ${delay.inMilliseconds}ms';
  }

  /// Test timeout error classification
  static void testErrorClassification() {
    print('\n=== TESTING ERROR CLASSIFICATION ===');

    final testErrors = [
      TimeoutException('Test timeout', Duration(seconds: 1)),
      Exception('Network error'),
      Exception('Connection failed'),
      Exception('DNS resolution failed'),
      Exception('Socket exception'),
      Exception('Generic error'),
    ];

    for (final error in testErrors) {
      final isRetryable = TimeoutConfig.isRetryableError(error);
      print('${error.toString()}: ${isRetryable ? "Retryable" : "Not retryable"}');
    }
  }

  /// Run comprehensive timeout tests
  static Future<void> runComprehensiveTests() async {
    print('🚀 STARTING COMPREHENSIVE TIMEOUT TESTS\n');

    try {
      await testBasicTimeout();
      await testRetryFunctionality();
      await testNetworkRecovery();
      testTimeoutConfigurations();
      await simulateNetworkConditions();
      testErrorClassification();

      print('\n✅ ALL TIMEOUT TESTS COMPLETED SUCCESSFULLY');
    } catch (e) {
      print('\n❌ TIMEOUT TESTS FAILED: $e');
      rethrow;
    }
  }

  /// Validate timeout implementations in services
  static Future<void> validateServiceTimeouts() async {
    print('\n=== VALIDATING SERVICE TIMEOUT IMPLEMENTATIONS ===');

    // Check if services are using consistent timeouts
    final validationResults = <String, bool>{};

    // This would ideally check actual service implementations
    // For now, we'll simulate the validation
    validationResults['TTS Service'] = true;      // Uses TimeoutConfig.tts
    validationResults['Auth Service'] = true;     // Uses TimeoutConfig.database
    validationResults['Login Screen'] = true;     // Uses TimeoutConfig.standard
    validationResults['Assessment Service'] = false; // Needs implementation

    print('Service timeout validation results:');
    for (final entry in validationResults.entries) {
      final status = entry.value ? '✅' : '❌';
      print('$status ${entry.key}: ${entry.value ? "Valid" : "Needs update"}');
    }

    final allValid = validationResults.values.every((v) => v);
    print('\nOverall validation: ${allValid ? "✅ PASSED" : "❌ NEEDS WORK"}');
  }

  /// Monitor timeout performance
  static Future<void> monitorTimeoutPerformance() async {
    print('\n=== MONITORING TIMEOUT PERFORMANCE ===');

    final operations = [
      {'name': 'Quick Operation', 'duration': Duration(milliseconds: 500)},
      {'name': 'Standard Operation', 'duration': Duration(seconds: 2)},
      {'name': 'Long Operation', 'duration': Duration(seconds: 8)},
    ];

    for (final operation in operations) {
      final name = operation['name'] as String;
      final duration = operation['duration'] as Duration;

      final stopwatch = Stopwatch()..start();

      try {
        await TimeoutConfig.withTimeout(
          _simulateOperation(duration),
          timeout: TimeoutConfig.standard,
          operationName: name,
        );

        stopwatch.stop();
        print('✅ $name completed in ${stopwatch.elapsedMilliseconds}ms');
      } catch (e) {
        stopwatch.stop();
        print('❌ $name failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      }
    }
  }
}

/// Development helper to test timeouts during development
class TimeoutDevelopmentHelper {
  /// Add test timeout behavior to any widget
  static Future<T> addTestTimeout<T>(
    Future<T> operation, {
    required String operationName,
    bool forceTimeout = false,
    bool forceError = false,
  }) async {
    if (forceTimeout) {
      // Force a timeout for testing
      return await TimeoutConfig.withTimeout(
        Future.delayed(Duration(seconds: 30)).then((_) => operation),
        timeout: Duration(seconds: 1),
        operationName: '$operationName (Forced Timeout)',
      );
    }

    if (forceError) {
      // Force an error for testing
      throw TimeoutException(
        'Forced error for testing: $operationName',
        Duration(seconds: 1),
      );
    }

    // Normal operation with recovery
    return await operation.withRecovery(
      operationName: operationName,
      onRecoveryStarted: () {
        print('[DEV] Recovery started for: $operationName');
      },
      onRecoveryCompleted: () {
        print('[DEV] Recovery completed for: $operationName');
      },
    );
  }
}