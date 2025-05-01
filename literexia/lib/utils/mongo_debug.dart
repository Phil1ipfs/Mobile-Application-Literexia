// lib/utils/mongo_debug.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MongoDebug {
  // Check platform details and print diagnostic info
  static void printPlatformInfo() {
    print('\n===== PLATFORM INFO =====');
    print('kIsWeb: $kIsWeb');

    if (!kIsWeb) {
      // Only available on non-web platforms
      String platform = 'Unknown';
      try {
        if (defaultTargetPlatform == TargetPlatform.android) {
          platform = 'Android';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          platform = 'iOS';
        } else if (defaultTargetPlatform == TargetPlatform.macOS) {
          platform = 'macOS';
        } else if (defaultTargetPlatform == TargetPlatform.windows) {
          platform = 'Windows';
        } else if (defaultTargetPlatform == TargetPlatform.linux) {
          platform = 'Linux';
        } else if (defaultTargetPlatform == TargetPlatform.fuchsia) {
          platform = 'Fuchsia';
        }
      } catch (e) {
        platform = 'Error detecting: $e';
      }
      print('Platform: $platform');
    } else {
      print('Platform: Web Browser');
    }
    print('========================\n');
  }

  // Check if the .env file is properly loaded and parse the MongoDB URI
  static void checkMongoURI() {
    print('\n===== MONGO URI CHECK =====');

    // Check if env vars are loaded
    final mongoUri = dotenv.env['MONGO_URI'];
    print('MONGO_URI loaded: ${mongoUri != null && mongoUri.isNotEmpty}');

    if (mongoUri != null && mongoUri.isNotEmpty) {
      // Parse the URI to check its components
      try {
        // Basic URI parsing
        final uriParts = mongoUri.split('@');

        if (uriParts.length > 1) {
          // Extract protocol and credentials
          final protoParts = uriParts[0].split('://');
          final protocol = protoParts[0];

          // Extract host and options
          final hostParts = uriParts[1].split('/');
          final host = hostParts[0];

          // Extract database name if present
          String dbName = 'None specified';
          if (hostParts.length > 1 && hostParts[1].isNotEmpty) {
            final dbParts = hostParts[1].split('?');
            dbName = dbParts[0];
          }

          print('Protocol: $protocol');
          print('Host: $host');
          print('Database: $dbName');

          // Check for options
          if (mongoUri.contains('?')) {
            final optionsPart = mongoUri.split('?')[1];
            final options = optionsPart.split('&');
            print('Connection options: ${options.join(', ')}');
          }

          print('URI Format: VALID');
        } else {
          print('URI Format: INVALID - Missing @ separator');
        }
      } catch (e) {
        print('Error parsing URI: $e');
        print('URI Format: INVALID');
      }
    } else {
      print('Cannot check URI: Not found in environment variables');
    }
    print('==========================\n');
  }

  // Test basic encoding/decoding functions to ensure they're working
  static void testEncodingFunctions() {
    print('\n===== ENCODING TEST =====');
    try {
      // Test JSON encoding/decoding
      final testMap = {
        'test': 'value',
        'number': 42,
        'list': [1, 2, 3],
      };

      final encoded = jsonEncode(testMap);
      final decoded = jsonDecode(encoded);

      print(
        'JSON encode/decode: ${decoded['test'] == 'value' ? 'WORKING' : 'FAILED'}',
      );

      // Test base64 encoding/decoding
      final testString = 'Hello MongoDB!';
      final base64Encoded = base64Encode(utf8.encode(testString));
      final base64Decoded = utf8.decode(base64Decode(base64Encoded));

      print(
        'Base64 encode/decode: ${base64Decoded == testString ? 'WORKING' : 'FAILED'}',
      );
    } catch (e) {
      print('Encoding test error: $e');
    }
    print('========================\n');
  }
}
