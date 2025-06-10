// lib/features/settings/widgets/voice_selection.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/settings/provider/tts_provider.dart';

class VoiceSelectionWidget extends StatelessWidget {
  const VoiceSelectionWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ttsProvider = Provider.of<TTSProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'VOICE',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        if (ttsProvider.availableVoices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('No voices available'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade400,
                borderRadius: BorderRadius.circular(25),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: ttsProvider.currentVoice,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      ttsProvider.setVoice(newValue);
                    }
                  },
                  items: ttsProvider.availableVoices
                      .map<DropdownMenuItem<String>>((voice) {
                    final name =
                        voice['name'] ?? voice['voiceName'] ?? 'Unknown Voice';
                    final locale = voice['locale'] ?? voice['language'] ?? '';
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          '$name${locale.isNotEmpty ? ' ($locale)' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  dropdownColor: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(16),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                ),
              ),
            ),
          ),

        // Debug button to show available voices
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Available Voices'),
                  content: SingleChildScrollView(
                    child: Text(ttsProvider.getVoicesDebugInfo()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('SHOW AVAILABLE VOICES'),
          ),
        ),
      ],
    );
  }
}
