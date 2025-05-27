// File: android/app/src/main/kotlin/com/example/literexia/MainActivity.kt

package com.example.literexia

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.literexia/playht"
    private lateinit var playHTService: PlayHTService
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize the PlayHT service
        playHTService = PlayHTService(context)
        
        // Set up the method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            playHTService.handleMethodCall(call, result)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Clean up resources
        playHTService.dispose()
    }
}