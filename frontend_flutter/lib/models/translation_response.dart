class Sign {
  final String label; // The identifier for the sign, e.g., "Ayubowan"
  final String? videoPath;
  final String? animationPath;
  final List<List<double>>? landmarkData; // Optional landmark data for animation
  final String? landmarkPath; // Path to landmark file for fetching

  Sign({
    required this.label,
    this.videoPath,
    this.animationPath,
    this.landmarkData,
    this.landmarkPath,
  });

  factory Sign.fromJson(Map<String, dynamic> json) {
    // Parse landmark data if it exists
    List<List<double>>? landmarks;
    String? landmarkFilePath;
    
    if (json.containsKey('landmark_data') && json['landmark_data'] != null) {
      final landmarkDataValue = json['landmark_data'];
      
      // Handle different formats of landmark_data
      if (landmarkDataValue is List) {
        // Format 1: Actual coordinate data (List of frames)
        try {
          final List<dynamic> framesJson = landmarkDataValue as List<dynamic>;
          landmarks = framesJson
              .map((frame) => (frame as List<dynamic>).cast<double>().toList())
              .toList();
          print('✅ Parsed ${landmarks.length} frames of landmark coordinates');
        } catch (e) {
          print('⚠️ Failed to parse landmark coordinate data: $e');
          landmarks = null;
        }
      } else if (landmarkDataValue is String) {
        // Format 2: Either S3 URL or file path to landmark data
        if (landmarkDataValue.startsWith('http')) {
          // It's a pre-signed S3 URL, store it for fetching
          landmarkFilePath = landmarkDataValue;
          landmarks = null; // Will be fetched later using the URL
          print('🌐 Landmark data is S3 URL: ${landmarkDataValue.substring(0, 100)}...');
        } else {
          // It's a local file path, store it for fetching
          landmarkFilePath = landmarkDataValue;
          landmarks = null; // Will be fetched later using the path
          print('📄 Landmark data is a file path: $landmarkDataValue');
        }
      } else {
        print('⚠️ Unknown landmark_data format: ${landmarkDataValue.runtimeType}');
        landmarks = null;
      }
    }

    return Sign(
      label: json['label'] as String,
      videoPath: json['video_path'] as String?,
      animationPath: json['animation_path'] as String?,
      landmarkData: landmarks,
      landmarkPath: landmarkFilePath,
    );
  }
}

class TranslationResponse {
  final List<Sign> signs;

  TranslationResponse({required this.signs});

  factory TranslationResponse.fromJson(Map<String, dynamic> json) {
    // Safely parse the signs array with better error handling
    List<Sign> signs = [];
    
    if (json.containsKey('signs') && json['signs'] != null) {
      final signsValue = json['signs'];
      
      if (signsValue is List) {
        try {
          final List<dynamic> signsJson = signsValue as List<dynamic>;
          signs = signsJson.map((signJson) => Sign.fromJson(signJson)).toList();
          print('✅ Successfully parsed ${signs.length} signs from response');
        } catch (e) {
          print('❌ Error parsing signs array: $e');
          signs = []; // Return empty list on parsing error
        }
      } else {
        print('⚠️ Expected signs to be a List, but got: ${signsValue.runtimeType}');
        print('📄 Signs value: $signsValue');
        signs = []; // Return empty list if not a list
      }
    } else {
      print('⚠️ No "signs" key found in response or it is null');
      signs = []; // Return empty list if no signs key
    }
    
    return TranslationResponse(signs: signs);
  }
} 