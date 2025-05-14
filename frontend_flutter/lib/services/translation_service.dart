import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/translation_response.dart';

class TranslationService {
  static String get _baseUrl => dotenv.env['BACKEND_URL'] ?? 'http://127.0.0.1:8080';
  
  // Translate text to sign language
  static Future<TranslationResponse> translateTextToSign(String text, String language) async {
    const String endpoint = '/api/translate/text-to-slsl';
    
    try {
      print('Sending request to $_baseUrl$endpoint with text: \'$text\' in language: $language');
      
      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'source_language': language
        }),
      );
      
      if (response.statusCode == 200) {
        print('Translation successful:');
        print(response.body);
        
        final data = jsonDecode(response.body);
        return TranslationResponse.fromJson(data);
      } else {
        print('Translation failed: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to translate text: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('API error: $e');
      throw Exception('API error: $e');
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