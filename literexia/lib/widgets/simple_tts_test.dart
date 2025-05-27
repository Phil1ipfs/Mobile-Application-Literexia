// // lib/widgets/simple_tts_test.dart
// // Create this file to test TTS functionality on any screen

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../features/settings/provider/theme_provider.dart';
// import '../features/settings/provider/tts_provider.dart';

// class SimpleTTSTest extends StatefulWidget {
//   final String testText;
//   final bool autoplay;
//   final bool forceEnable;
//   final bool showControls;

//   const SimpleTTSTest({
//     Key? key,
//     required this.testText,
//     this.autoplay = false,
//     this.forceEnable = false,
//     this.showControls = true,
//   }) : super(key: key);

//   @override
//   State<SimpleTTSTest> createState() => _SimpleTTSTestState();
// }

// class _SimpleTTSTestState extends State<SimpleTTSTest> {
//   @override
//   void initState() {
//     super.initState();
//     if (widget.autoplay) {
//       // Use a post-frame callback to ensure the context is available
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         final ttsProvider = Provider.of<TTSProvider>(context, listen: false);
//         if (widget.forceEnable || ttsProvider.isAvailable) {
//           ttsProvider.speak(widget.testText);
//         }
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);
//     final ttsProvider = Provider.of<TTSProvider>(context);
//     final theme = themeProvider.currentTheme;

//     // If we're forcing enable, we'll ignore the TTS provider's availability
//     final isAvailable = widget.forceEnable || ttsProvider.isAvailable;

//     return Card(
//       color: theme.primaryColor,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: BorderSide(color: theme.accentColor, width: 2),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             if (!widget.forceEnable) ...[
//               Text(
//                 'TTS Test Widget',
//                 style: TextStyle(
//                   color: theme.textColor,
//                   fontSize: themeProvider.getRealFontSize(16),
//                   fontWeight: FontWeight.bold,
//                   fontFamily: themeProvider.fontFamily,
//                 ),
//               ),
//               const SizedBox(height: 12),
//             ],
//             Text(
//               widget.testText,
//               style: TextStyle(
//                 color: theme.textColor,
//                 fontSize: themeProvider.getRealFontSize(14),
//                 fontFamily: themeProvider.fontFamily,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             if (widget.showControls) ...[
//               const SizedBox(height: 16),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   // Play button
//                   ElevatedButton.icon(
//                     onPressed: isAvailable && !ttsProvider.isPlaying
//                         ? () => ttsProvider.speak(widget.testText)
//                         : null,
//                     icon: const Icon(Icons.play_arrow),
//                     label: const Text('Play'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: theme.accentColor,
//                       foregroundColor: theme.buttonTextColor,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   // Stop button
//                   ElevatedButton.icon(
//                     onPressed: ttsProvider.isPlaying
//                         ? () => ttsProvider.stop()
//                         : null,
//                     icon: const Icon(Icons.stop),
//                     label: const Text('Stop'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               if (!widget.forceEnable)
//                 Text(
//                   'TTS Status: ${isAvailable ? (ttsProvider.isEnabled ? "Enabled" : "Disabled") : "Not Available"}',
//                   style: TextStyle(
//                     color: theme.textColor.withOpacity(0.7),
//                     fontSize: themeProvider.getRealFontSize(12),
//                     fontFamily: themeProvider.fontFamily,
//                   ),
//                 ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }