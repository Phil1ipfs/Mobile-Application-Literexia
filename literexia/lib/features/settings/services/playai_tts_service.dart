import 'package:flutter/material.dart';

class PlayAITTSService {
  static PlayAITTSService? _instance;
  static PlayAITTSService get instance => _instance ??= PlayAITTSService._();
  PlayAITTSService._();
  
  bool _isPlaying = false;
  bool _isLoading = false;
  
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  
  Future<bool> isAvailable() async {
    // For now, always return true since we're mocking
    return true;
  }
  
  Future<bool> speak(String text, {
    bool cache = true,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    print('[PlayAI TTS] Speaking: ${text.substring(0, text.length.clamp(0, 50))}...');
    
    _isLoading = true;
    onStart?.call();
    
    // Simulate loading time
    await Future.delayed(Duration(milliseconds: 500));
    
    _isLoading = false;
    _isPlaying = true;
    
    // Simulate speaking time based on text length
    final speakingTime = (text.length * 60).clamp(1000, 5000);
    await Future.delayed(Duration(milliseconds: speakingTime));
    
    _isPlaying = false;
    onComplete?.call();
    
    print('[PlayAI TTS] Completed speaking');
    return true;
  }
  
  Future<void> stop() async {
    _isPlaying = false;
    _isLoading = false;
    print('[PlayAI TTS] Stopped');
  }
  
  void clearCache() {
    // Mock implementation - no actual cache to clear
    print('[PlayAI TTS] Cache cleared');
  }
  
  void dispose() {
    _isPlaying = false;
    _isLoading = false;
  }
} 