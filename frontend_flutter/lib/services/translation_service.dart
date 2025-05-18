import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/translation_response.dart';

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
    
    print('TranslationService: Sending request to $uri');
    print('TranslationService: Request body: ${jsonEncode({
          'text': text,
          'source_language': language,
          'target_language': 'lk-sign', // Assuming target is always Sri Lankan Sign Language
        })}');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'source_language': language,
          'target_language': 'lk-sign', // Kept as per previous refactor, backend might ignore if endpoint is specific
        }),
      );

      print('TranslationService: Response status code: ${response.statusCode}');
      // print('TranslationService: Response body: ${response.body}');

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
            print('TranslationService Error: "signs" key not found within response or "translation" object.');
            throw Exception('Failed to parse translation: "signs" key missing in translation data');
        }

      } else {
        print('TranslationService Error: API request failed with status ${response.statusCode}: ${response.body}');
        throw Exception('Failed to translate text: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('TranslationService Error: Exception during API call: $e');
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