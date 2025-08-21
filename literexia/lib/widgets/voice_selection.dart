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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const Text('No voices available'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    await ttsProvider.refreshConnection();
                  },
                  child: const Text('Refresh Voices'),
                ),
              ],
            ),
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
                    final name = voice['name'] ?? 'Unknown Voice';
                    final voiceId = voice['id'] ?? voice['name'] ?? 'no-id';
                    final language = voice['language'] ?? voice['language_code'] ?? '';
                    
                    // Debug: print voice structure
                    print('Voice item: $voice');
                    print('Voice ID: $voiceId, Name: $name');
                    
                    return DropdownMenuItem<String>(
                      value: voiceId,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          '$name${language.isNotEmpty ? ' ($language)' : ''}',
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

        // Debug information
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TTS Status: ${ttsProvider.isAvailable ? "Available" : "Not Available"}'),
              Text('Current Voice: ${ttsProvider.currentVoice ?? "None"}'),
              Text('Voice Count: ${ttsProvider.availableVoices.length}'),
              Text('Connection Status: ${ttsProvider.connectionStatus}'),
              if (ttsProvider.lastError.isNotEmpty)
                Text('Last Error: ${ttsProvider.lastError}', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('TTS Debug Info'),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Available: ${ttsProvider.isAvailable}'),
                            Text('Voice Count: ${ttsProvider.availableVoices.length}'),
                            Text('Current Voice: ${ttsProvider.currentVoice}'),
                            Text('Status: ${ttsProvider.connectionStatus}'),
                            const SizedBox(height: 16),
                            const Text('Available Voices:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(ttsProvider.getVoicesDebugInfo()),
                          ],
                        ),
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
                child: const Text('SHOW DEBUG INFO'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
