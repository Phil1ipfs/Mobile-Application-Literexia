import 'dart:typed_data';
import 'package:flutter/material.dart';

class MockTTSService {
  static MockTTSService? _instance;
  static MockTTSService get instance => _instance ??= MockTTSService._();
  MockTTSService._();
  
  bool _isPlaying = false;
  bool _isLoading = false;
  
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isAvailable => true; // Mock is always available
  
  Future<bool> speak(String text, {
    bool cache = true,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    print('[Mock TTS] Speaking: ${text.substring(0, text.length.clamp(0, 50))}...');
    
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
    
    print('[Mock TTS] Completed speaking');
    return true;
  }
  
  Future<void> stop() async {
    _isPlaying = false;
    _isLoading = false;
    print('[Mock TTS] Stopped');
  }
  
  void clearCache() {
    // Mock implementation - no actual cache to clear
    print('[Mock TTS] Cache cleared');
  }
  
  void dispose() {
    _isPlaying = false;
    _isLoading = false;
  }
} 