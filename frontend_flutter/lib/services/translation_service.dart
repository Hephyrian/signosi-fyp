import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/translation_response.dart';

class ApiLogger {
  static const String _tag = '[API_REQUEST]';
  
  static void logRequest(String method, String url, Map<String, dynamic>? body, Map<String, String>? headers) {
    print('$_tag $method Request to: $url');
    if (headers != null) {
      print('$_tag Headers: ${jsonEncode(headers)}');
    }
    if (body != null) {
      print('$_tag Request Body: ${jsonEncode(body)}');
    }
  }
  
  static void logResponse(String url, int statusCode, String responseBody) {
    print('$_tag Response from: $url');
    print('$_tag Status Code: $statusCode');
    if (statusCode == 200) {
      print('$_tag Response Body: ${responseBody.length > 500 ? '${responseBody.substring(0, 500)}...[TRUNCATED]' : responseBody}');
    } else {
      print('$_tag Error Response: $responseBody');
    }
  }
  
  static void logError(String url, String error) {
    print('$_tag ERROR for $url: $error');
  }
}

class TranslationService {
  // Base URL for the translation API, loaded from .env or default
  static final String _apiBaseUrl = dotenv.env['BACKEND_URL'] ?? 'http://127.0.0.1:8080';

  static Future<TranslationResponse> translateTextToSign(
    String text, 
    String language,
    {String? baseUrl} // Add optional baseUrl parameter
  ) async {
    final String apiUrl = baseUrl ?? _apiBaseUrl; // Use provided baseUrl or default
    final Uri uri = Uri.parse('$apiUrl/api/translate/text-to-slsl');
    
    final requestBody = {
      'text': text,
      'source_language': language,
      'target_language': 'lk-sign', // Assuming target is always Sri Lankan Sign Language
    };
    
    final headers = {'Content-Type': 'application/json'};
    
    // Enhanced logging with timestamp
    final timestamp = DateTime.now().toIso8601String();
    print('🚀 [$timestamp] TranslationService: Starting translation request');
    ApiLogger.logRequest('POST', uri.toString(), requestBody, headers);

    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      final responseTimestamp = DateTime.now().toIso8601String();
      print('✅ [$responseTimestamp] TranslationService: Translation request completed');
      ApiLogger.logResponse(uri.toString(), response.statusCode, response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        // Check if the 'translation' key exists and contains the 'signs'
        // This parsing expects the backend to return a structure like: 
        // { "translation": { "signs": [ ... ] } } or directly { "signs": [ ... ] }
        // Adjust if backend returns a different structure for the /api/translate/text-to-slsl endpoint.
        
        if (responseData.containsKey('translation') && 
            responseData['translation'] is Map && 
            (responseData['translation'] as Map).containsKey('signs')) {
            final Map<String, dynamic> translationData = responseData['translation'];
            return TranslationResponse.fromJson(translationData);
        } else if (responseData.containsKey('signs')) {
            // Handle cases where the response might be directly {"signs": [...]} e.g. if endpoint is very specific
            return TranslationResponse.fromJson(responseData);
        } else {
            final errorMsg = 'TranslationService Error: "signs" key not found within response or "translation" object.';
            print('❌ $errorMsg');
            ApiLogger.logError(uri.toString(), errorMsg);
            throw Exception('Failed to parse translation: "signs" key missing in translation data');
        }

      } else {
        final errorMsg = 'API request failed with status ${response.statusCode}: ${response.body}';
        print('❌ TranslationService Error: $errorMsg');
        ApiLogger.logError(uri.toString(), errorMsg);
        throw Exception('Failed to translate text: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      final errorMsg = 'Exception during API call: $e';
      print('❌ TranslationService Error: $errorMsg');
      ApiLogger.logError(uri.toString(), errorMsg);
      throw Exception('Failed to connect to the translation service: $e');
    }
  }
  
  // Utility method to extract the filename from a path
  static String getFilenameFromPath(String path) {
    final pathSegments = path.split('\\');
    return pathSegments.isNotEmpty ? pathSegments.last : '';
  }
  
  // Method to check if video file exists and is accessible
  static bool isVideoFileAccessible(String path) {
    try {
      final file = Uri.file(path).toFilePath();
      return true;
    } catch (e) {
      print('Error checking video file: $e');
      return false;
    }
  }
} 