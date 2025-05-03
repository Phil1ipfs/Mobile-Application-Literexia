// // lib/utils/db_diagnostics.dart
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import '../services/database_service.dart';

// class DbDiagnostics {
//   /// Run all diagnostics and return results
//   static Future<Map<String, dynamic>> runDiagnostics() async {
//     final results = <String, dynamic>{};

//     // Check platform
//     results['platform'] = _getPlatformInfo();

//     // Check environment variables
//     results['env_variables'] = await _checkEnvVariables();

//     // Check network connectivity
//     results['network'] = await _checkNetworkConnectivity();

//     // Check database connection
//     results['database'] = await _checkDatabaseConnection();

//     return results;
//   }

//   /// Get platform information
//   static Map<String, dynamic> _getPlatformInfo() {
//     return {
//       'is_web': kIsWeb,
//       'platform': kIsWeb ? 'web' : Platform.operatingSystem,
//       'version': kIsWeb ? 'unknown' : Platform.operatingSystemVersion,
//     };
//   }

//   /// Check environment variables
//   static Future<Map<String, dynamic>> _checkEnvVariables() async {
//     final results = <String, dynamic>{};

//     try {
//       // Try to reload env variables to ensure they're loaded
//       await dotenv.load(fileName: ".env");
//       results['dotenv_loaded'] = true;
//     } catch (e) {
//       results['dotenv_loaded'] = false;
//       results['dotenv_error'] = e.toString();
//     }

//     // Check if MONGO_URI exists and is properly formatted
//     final mongoUri = dotenv.env['MONGO_URI'];
//     results['mongo_uri_exists'] = mongoUri != null && mongoUri.isNotEmpty;

//     if (results['mongo_uri_exists']) {
//       final dbService = DatabaseService();
//       results['mongo_uri_masked'] = dbService._maskUri(mongoUri!);

//       // Check URI format
//       results['mongo_uri_format_valid'] = _isMongoUriFormatValid(mongoUri);
//     }

//     return results;
//   }

//   /// Check if MongoDB URI is properly formatted
//   static bool _isMongoUriFormatValid(String uri) {
//     try {
//       return uri.startsWith('mongodb://') || uri.startsWith('mongodb+srv://');
//     } catch (_) {
//       return false;
//     }
//   }

//   /// Check network connectivity
//   static Future<Map<String, dynamic>> _checkNetworkConnectivity() async {
//     final results = <String, dynamic>{};

//     if (kIsWeb) {
//       results['status'] = 'skipped_web';
//       return results;
//     }

//     try {
//       // Try to ping common hosts
//       const hosts = ['www.google.com', 'www.mongodb.com', 'www.github.com'];

//       for (final host in hosts) {
//         try {
//           final lookupResult = await InternetAddress.lookup(host);
//           results[host] = {
//             'success': lookupResult.isNotEmpty,
//             'addresses': lookupResult.map((addr) => addr.address).toList(),
//           };
//         } catch (e) {
//           results[host] = {'success': false, 'error': e.toString()};
//         }
//       }

//       // Try to parse MongoDB host from URI
//       final mongoUri = dotenv.env['MONGO_URI'];
//       if (mongoUri != null && mongoUri.isNotEmpty) {
//         try {
//           final uriParts = mongoUri.split('@');
//           if (uriParts.length > 1) {
//             final hostPart = uriParts[1].split('/')[0];
//             final mongoHost = hostPart.split(':')[0];

//             try {
//               final lookupResult = await InternetAddress.lookup(mongoHost);
//               results['mongodb_host'] = {
//                 'host': mongoHost,
//                 'success': lookupResult.isNotEmpty,
//                 'addresses': lookupResult.map((addr) => addr.address).toList(),
//               };
//             } catch (e) {
//               results['mongodb_host'] = {
//                 'host': mongoHost,
//                 'success': false,
//                 'error': e.toString(),
//               };
//             }
//           }
//         } catch (e) {
//           results['mongodb_host_parse'] = {
//             'success': false,
//             'error': e.toString(),
//           };
//         }
//       }
//     } catch (e) {
//       results['status'] = 'error';
//       results['error'] = e.toString();
//     }

//     return results;
//   }

//   /// Check database connection
//   static Future<Map<String, dynamic>> _checkDatabaseConnection() async {
//     final results = <String, dynamic>{};

//     try {
//       final dbService = DatabaseService();

//       // Check initialization status
//       results['is_initialized'] = dbService.isInitialized;
//       results['is_connected'] = dbService.isConnected;
//       results['connection_error'] = dbService.connectionError;

//       // Try to initialize if not already initialized
//       if (!dbService.isInitialized) {
//         final initResult = await dbService.initialize();
//         results['init_attempt'] = initResult;
//         results['is_initialized'] = dbService.isInitialized;
//         results['is_connected'] = dbService.isConnected;
//         results['connection_error'] = dbService.connectionError;
//       }

//       // Try to ping database
//       final pingResult = await dbService.testConnection();
//       results['ping_success'] = pingResult;

//       // Try to list collections (if connected)
//       if (dbService.isConnected) {
//         try {
//           // Access collections through the service's getCollection method
//           // We'll try to access a known collection to test connection
//           final testCollection = dbService.getCollection('users');
//           final collectionExists = await testCollection.count() > 0;
//           results['users_collection_exists'] = collectionExists;

//           // Get count of documents in the collection
//           if (collectionExists) {
//             final count = await testCollection.count();
//             results['users_document_count'] = count;
//           }
//         } catch (e) {
//           results['collections_error'] = e.toString();
//         }
//       }
//     } catch (e) {
//       results['status'] = 'error';
//       results['error'] = e.toString();
//     }

//     return results;
//   }

//   /// Log diagnostic results in a readable format
//   static void printDiagnostics(Map<String, dynamic> results) {
//     print('\n========== DATABASE DIAGNOSTICS ==========');

//     // Print platform info
//     final platform = results['platform'] as Map<String, dynamic>;
//     print('\n-- PLATFORM --');
//     print('Running on: ${platform['platform']} ${platform['version']}');
//     print('Is Web: ${platform['is_web']}');

//     // Print env variables
//     final env = results['env_variables'] as Map<String, dynamic>;
//     print('\n-- ENVIRONMENT VARIABLES --');
//     print('dotenv loaded: ${env['dotenv_loaded']}');
//     if (env['dotenv_error'] != null) {
//       print('dotenv error: ${env['dotenv_error']}');
//     }
//     print('MONGO_URI exists: ${env['mongo_uri_exists']}');
//     if (env['mongo_uri_exists']) {
//       print('MONGO_URI format valid: ${env['mongo_uri_format_valid']}');
//       print('MONGO_URI (masked): ${env['mongo_uri_masked']}');
//     }

//     // Print network connectivity
//     final network = results['network'] as Map<String, dynamic>;
//     print('\n-- NETWORK CONNECTIVITY --');
//     if (network['status'] == 'skipped_web') {
//       print('Network check skipped on web platform');
//     } else if (network['status'] == 'error') {
//       print('Network check error: ${network['error']}');
//     } else {
//       network.forEach((key, value) {
//         if (value is Map<String, dynamic>) {
//           if (value['success']) {
//             print('$key: SUCCESS');
//           } else {
//             print('$key: FAILED - ${value['error']}');
//           }
//         }
//       });
//     }

//     // Print database connection
//     final db = results['database'] as Map<String, dynamic>;
//     print('\n-- DATABASE CONNECTION --');
//     print('Initialized: ${db['is_initialized']}');
//     print('Connected: ${db['is_connected']}');
//     if (db['connection_error'] != null) {
//       print('Connection error: ${db['connection_error']}');
//     }
//     print('Ping success: ${db['ping_success']}');
//     if (db['users_collection_exists'] != null) {
//       print('Users collection exists: ${db['users_collection_exists']}');
//     }
//     if (db['users_document_count'] != null) {
//       print('Users document count: ${db['users_document_count']}');
//     }
//     if (db['collections_error'] != null) {
//       print('Collections error: ${db['collections_error']}');
//     }

//     print('\n==========================================\n');
//   }
// }
