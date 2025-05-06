// // lib/widgets/connection_status_widget.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../services/database_service.dart';

// class ConnectionStatusWidget extends StatelessWidget {
//   final bool showDetailedStatus;

//   const ConnectionStatusWidget({Key? key, this.showDetailedStatus = false})
//     : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final dbService = Provider.of<DatabaseService>(context, listen: false);
//     final isConnected = dbService.isConnected;

//     return showDetailedStatus
//         ? _buildDetailedStatus(dbService)
//         : _buildSimpleStatus(isConnected);
//   }

//   // Simple connection indicator
//   Widget _buildSimpleStatus(bool isConnected) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: isConnected ? Colors.green : Colors.red,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             isConnected ? Icons.cloud_done : Icons.cloud_off,
//             color: Colors.white,
//             size: 16,
//           ),
//           const SizedBox(width: 4),
//           Text(
//             isConnected ? 'DB Connected' : 'DB Offline',
//             style: const TextStyle(color: Colors.white, fontSize: 12),
//           ),
//         ],
//       ),
//     );
//   }

//   // Detailed connection status card
//   Widget _buildDetailedStatus(DatabaseService dbService) {
//     final isConnected = dbService.isConnected;
//     final error = dbService.connectionError;

//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Row(
//               children: [
//                 Icon(
//                   isConnected ? Icons.check_circle : Icons.error,
//                   color: isConnected ? Colors.green : Colors.red,
//                 ),
//                 const SizedBox(width: 8),
//                 Text(
//                   'Database Status: ${isConnected ? 'Connected' : 'Disconnected'}',
//                   style: const TextStyle(fontWeight: FontWeight.bold),
//                 ),
//               ],
//             ),
//             if (error != null) ...[
//               const SizedBox(height: 8),
//               Text(
//                 'Error: $error',
//                 style: const TextStyle(color: Colors.red, fontSize: 12),
//               ),
//             ],
//             const SizedBox(height: 8),
//             const Text(
//               'Note: Make sure your MongoDB is properly configured with integer IDs.',
//               style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
