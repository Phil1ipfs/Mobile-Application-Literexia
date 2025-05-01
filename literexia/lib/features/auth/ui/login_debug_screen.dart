// // lib/features/auth/ui/login_debug_screen.dart
// import 'package:flutter/material.dart';
// import '../logic/auth_provider.dart';
// import '../../../repositories/user_repository.dart';
// import 'package:provider/provider.dart';

// class LoginDebugScreen extends StatefulWidget {
//   const LoginDebugScreen({Key? key}) : super(key: key);

//   @override
//   _LoginDebugScreenState createState() => _LoginDebugScreenState();
// }

// class _LoginDebugScreenState extends State<LoginDebugScreen> {
//   final _idController = TextEditingController();
//   final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
//   bool _isLoading = false;
//   String _debugOutput = '';
//   bool _dbConnected = false;
//   final UserRepository _userRepository = UserRepository();

//   @override
//   void initState() {
//     super.initState();
//     _checkDbConnection();
//   }

//   Future<void> _checkDbConnection() async {
//     try {
//       // This is a simple check to see if we can access the DB
//       final testQuery = await _userRepository.userExists('TESTQUERY');
//       setState(() {
//         _dbConnected = true;
//         _addDebugLog('✓ Database connection test successful');
//       });
//     } catch (e) {
//       setState(() {
//         _dbConnected = false;
//         _addDebugLog('✗ Database connection test failed: $e');
//       });
//     }
//   }

//   void _addDebugLog(String message) {
//     setState(() {
//       _debugOutput = '$message\n$_debugOutput';
//     });
//     print('[Login Debug] $message');
//   }

//   Future<void> _login() async {
//     final idNumber = _idController.text.trim();

//     if (idNumber.isEmpty) {
//       _scaffoldKey.currentState?.showSnackBar(
//         const SnackBar(content: Text('Please enter your ID number')),
//       );
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _addDebugLog('⚙️ Attempting login with ID: $idNumber');
//     });

//     try {
//       // First check if user exists
//       _addDebugLog('⚙️ Checking if user exists...');
//       final exists = await _userRepository.userExists(idNumber);
//       _addDebugLog(
//         exists ? '✓ User exists in database' : '✗ User not found in database',
//       );

//       if (exists) {
//         // If exists, try to get user details
//         _addDebugLog('⚙️ Retrieving user details...');
//         final user = await _userRepository.getUserByIdNumber(idNumber);
//         if (user != null) {
//           _addDebugLog('✓ User details retrieved: ${user.name}');

//           // Try the actual login flow
//           _addDebugLog('⚙️ Verifying login...');
//           final authProvider = Provider.of<AuthProvider>(
//             context,
//             listen: false,
//           );
//           final success = await authProvider.login(idNumber);

//           if (success) {
//             _addDebugLog('✓ Login successful');
//             // Login successful, navigate to home page
//             // Note: The auth provider should handle navigation
//           } else {
//             _addDebugLog('✗ AuthProvider login failed for unknown reason');
//             _scaffoldKey.currentState?.showSnackBar(
//               const SnackBar(content: Text('Login failed. Please try again.')),
//             );
//           }
//         } else {
//           _addDebugLog(
//             '✗ getUserByIdNumber returned null despite userExists=true',
//           );
//           _scaffoldKey.currentState?.showSnackBar(
//             const SnackBar(content: Text('Error retrieving user data')),
//           );
//         }
//       } else {
//         _addDebugLog('✗ User does not exist with ID: $idNumber');
//         _scaffoldKey.currentState?.showSnackBar(
//           const SnackBar(
//             content: Text(
//               'Invalid ID number. Please check with your administrator.',
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       _addDebugLog('✗ Error during login: $e');
//       _scaffoldKey.currentState?.showSnackBar(
//         SnackBar(content: Text('Login error: $e')),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ScaffoldMessenger(
//       key: _scaffoldKey,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Literexia Login'),
//           actions: [
//             // Connection status indicator
//             Container(
//               margin: const EdgeInsets.only(right: 16),
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: _dbConnected ? Colors.green : Colors.red,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Row(
//                 children: [
//                   Icon(
//                     _dbConnected ? Icons.cloud_done : Icons.cloud_off,
//                     color: Colors.white,
//                     size: 16,
//                   ),
//                   const SizedBox(width: 4),
//                   Text(
//                     _dbConnected ? 'DB Connected' : 'DB Offline',
//                     style: const TextStyle(color: Colors.white),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         body: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               // Error message for asset loading
//               if (MediaQuery.of(context).viewInsets.bottom ==
//                   0) // Only show when keyboard is closed
//                 Container(
//                   margin: const EdgeInsets.only(bottom: 16),
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.red.withOpacity(0.2),
//                     border: Border.all(color: Colors.red),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: const Text(
//                     'Unable to load asset: "assets/images/penguin.png"\nException: Asset not found',
//                     style: TextStyle(color: Colors.red),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),

//               // Login Box
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.amber.withOpacity(0.2),
//                   border: Border.all(color: Colors.amber),
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: const Text(
//                   'Maari mo bang ilagay ang iyong ID NUMBER?',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//               const SizedBox(height: 24),

//               // ID Input Field
//               TextField(
//                 controller: _idController,
//                 decoration: InputDecoration(
//                   hintText: 'Enter ID Number',
//                   prefixIcon: const Icon(Icons.person),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 keyboardType: TextInputType.number,
//               ),
//               const SizedBox(height: 16),

//               // Login Button
//               ElevatedButton(
//                 onPressed: _isLoading ? null : _login,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.amber,
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 child:
//                     _isLoading
//                         ? const CircularProgressIndicator(color: Colors.white)
//                         : const Text(
//                           'MAGPATULOY',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//               ),
//               const SizedBox(height: 8),
//               const Text(
//                 'No account yet? Please see your administrator.',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: Colors.grey),
//               ),

//               // Debug Log Section
//               const SizedBox(height: 24),
//               const Text(
//                 'Debug Log:',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               Expanded(
//                 child: Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: SingleChildScrollView(
//                     child: Text(
//                       _debugOutput.isEmpty
//                           ? 'No log entries yet.'
//                           : _debugOutput,
//                       style: const TextStyle(
//                         fontFamily: 'monospace',
//                         fontSize: 12,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
