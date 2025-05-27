// File: android/app/src/main/kotlin/com/example/literexia/PlayHTService.kt

package com.example.literexia

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * PlayHT Service for Flutter
 * 
 * Uses standard Java libraries instead of OkHttp
 */
class PlayHTService(private val context: Context) {
    
    private val TAG = "PlayHTService"
    private val executor = Executors.newSingleThreadExecutor()
    private var mediaPlayer: MediaPlayer? = null
    
    // This method handles Flutter method channel calls
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listVoices" -> {
                val apiKey = call.argument<String>("apiKey") ?: ""
                val userId = call.argument<String>("userId") ?: ""
                listVoices(apiKey, userId, result)
            }
            "generateSpeech" -> {
                val text = call.argument<String>("text") ?: ""
                val voiceId = call.argument<String>("voiceId") ?: ""
                val speed = call.argument<Double>("speed") ?: 1.0
                val apiKey = call.argument<String>("apiKey") ?: ""
                val userId = call.argument<String>("userId") ?: ""
                generateSpeech(text, voiceId, speed, apiKey, userId, result)
            }
            "playAudio" -> {
                val url = call.argument<String>("url") ?: ""
                playAudio(url, result)
            }
            "stopAudio" -> {
                stopAudio()
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    // List available voices from PlayHT API
    private fun listVoices(apiKey: String, userId: String, result: MethodChannel.Result) {
        executor.execute {
            try {
                val url = URL("https://api.play.ht/api/v2/voices")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.setRequestProperty("accept", "application/json")
                connection.setRequestProperty("Authorization", "Bearer $apiKey")
                connection.setRequestProperty("X-User-ID", userId)
                
                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val reader = BufferedReader(InputStreamReader(connection.inputStream))
                    val response = StringBuilder()
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        response.append(line)
                    }
                    reader.close()
                    
                    // Return voices to Flutter on the main thread
                    android.os.Handler(context.mainLooper).post {
                        result.success(response.toString())
                    }
                } else {
                    val errorStream = connection.errorStream
                    val reader = BufferedReader(InputStreamReader(errorStream))
                    val errorResponse = StringBuilder()
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        errorResponse.append(line)
                    }
                    reader.close()
                    
                    Log.e(TAG, "API Error: $responseCode - $errorResponse")
                    // Return error to Flutter on the main thread
                    android.os.Handler(context.mainLooper).post {
                        result.error("API_ERROR", "API Error: $responseCode", errorResponse.toString())
                    }
                }
                
                connection.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "Error fetching voices: ${e.message}")
                // Return error to Flutter on the main thread
                android.os.Handler(context.mainLooper).post {
                    result.error("NETWORK_ERROR", "Failed to fetch voices: ${e.message}", null)
                }
            }
        }
    }
    
    // Generate speech using PlayHT API
    private fun generateSpeech(text: String, voiceId: String, speed: Double, apiKey: String, userId: String, result: MethodChannel.Result) {
        executor.execute {
            try {
                // First, generate the audio ID
                val audioId = generateAudioId(text, voiceId, speed, apiKey, userId)
                
                if (audioId.isNotEmpty()) {
                    // Wait for processing
                    Thread.sleep(2000)
                    
                    // Get the audio URL using the generated ID
                    val audioUrl = getAudioUrl(audioId, apiKey, userId)
                    
                    if (audioUrl.isNotEmpty()) {
                        android.os.Handler(context.mainLooper).post {
                            result.success(audioUrl)
                        }
                    } else {
                        android.os.Handler(context.mainLooper).post {
                            result.error("API_ERROR", "No audio URL returned", null)
                        }
                    }
                } else {
                    android.os.Handler(context.mainLooper).post {
                        result.error("API_ERROR", "No audio ID returned", null)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error generating speech: ${e.message}")
                android.os.Handler(context.mainLooper).post {
                    result.error("NETWORK_ERROR", "Failed to generate speech: ${e.message}", null)
                }
            }
        }
    }
    
    // Generate audio ID from text
    private fun generateAudioId(text: String, voiceId: String, speed: Double, apiKey: String, userId: String): String {
        try {
            val url = URL("https://api.play.ht/api/v2/tts")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("accept", "application/json")
            connection.setRequestProperty("content-type", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $apiKey")
            connection.setRequestProperty("X-User-ID", userId)
            connection.doOutput = true
            
            // Create JSON request body
            val jsonBody = JSONObject().apply {
                put("text", text)
                put("voice", voiceId)
                put("speed", speed)
                put("output_format", "mp3")
            }
            
            // Write request body
            val writer = OutputStreamWriter(connection.outputStream)
            writer.write(jsonBody.toString())
            writer.flush()
            writer.close()
            
            val responseCode = connection.responseCode
            if (responseCode == HttpURLConnection.HTTP_OK || responseCode == HttpURLConnection.HTTP_CREATED) {
                val reader = BufferedReader(InputStreamReader(connection.inputStream))
                val response = StringBuilder()
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    response.append(line)
                }
                reader.close()
                
                val jsonResponse = JSONObject(response.toString())
                return jsonResponse.optString("id", "")
            } else {
                val errorStream = connection.errorStream
                val reader = BufferedReader(InputStreamReader(errorStream))
                val errorResponse = StringBuilder()
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    errorResponse.append(line)
                }
                reader.close()
                
                Log.e(TAG, "API Error: $responseCode - $errorResponse")
                return ""
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error generating audio ID: ${e.message}")
            return ""
        }
    }
    
    // Get audio URL from audio ID
    private fun getAudioUrl(audioId: String, apiKey: String, userId: String): String {
        try {
            val url = URL("https://api.play.ht/api/v2/tts/$audioId")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.setRequestProperty("accept", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $apiKey")
            connection.setRequestProperty("X-User-ID", userId)
            
            val responseCode = connection.responseCode
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val reader = BufferedReader(InputStreamReader(connection.inputStream))
                val response = StringBuilder()
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    response.append(line)
                }
                reader.close()
                
                val jsonResponse = JSONObject(response.toString())
                return jsonResponse.optString("audioUrl", "")
            } else {
                val errorStream = connection.errorStream
                val reader = BufferedReader(InputStreamReader(errorStream))
                val errorResponse = StringBuilder()
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    errorResponse.append(line)
                }
                reader.close()
                
                Log.e(TAG, "API Error: $responseCode - $errorResponse")
                return ""
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting audio URL: ${e.message}")
            return ""
        }
    }
    
    // Play audio from URL
    private fun playAudio(url: String, result: MethodChannel.Result) {
        // Stop any currently playing audio
        stopAudio()
        
        try {
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .build()
                )
                setDataSource(url)
                setOnPreparedListener { mp ->
                    mp.start()
                    android.os.Handler(context.mainLooper).post {
                        result.success(true)
                    }
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "Media player error: $what, $extra")
                    android.os.Handler(context.mainLooper).post {
                        result.error("PLAYBACK_ERROR", "Failed to play audio: $what, $extra", null)
                    }
                    true
                }
                setOnCompletionListener {
                    stopAudio()
                }
                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing audio: ${e.message}")
            result.error("PLAYBACK_ERROR", "Failed to play audio: ${e.message}", null)
        }
    }
    
    // Stop currently playing audio
    private fun stopAudio() {
        mediaPlayer?.apply {
            if (isPlaying) {
                stop()
            }
            reset()
            release()
        }
        mediaPlayer = null
    }
    
    // Clean up resources when the service is no longer needed
    fun dispose() {
        stopAudio()
        executor.shutdown()
    }
}