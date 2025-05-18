class Sign {
  final String mediaPath;
  final String? mediaType;
  final List<List<double>>? landmarkData; // Optional landmark data for animation

  Sign({
    required this.mediaPath,
    this.mediaType,
    this.landmarkData,
  });

  factory Sign.fromJson(Map<String, dynamic> json) {
    // Parse landmark data if it exists
    List<List<double>>? landmarks;
    if (json.containsKey('landmark_data') && json['landmark_data'] != null) {
      final List<dynamic> framesJson = json['landmark_data'] as List<dynamic>;
      landmarks = framesJson
          .map((frame) => (frame as List<dynamic>).cast<double>().toList())
          .toList();
    }

    return Sign(
      mediaPath: json['media_path'] as String,
      mediaType: json['media_type'] as String?,
      landmarkData: landmarks,
    );
  }
}

class TranslationResponse {
  final List<Sign> signs;

  TranslationResponse({required this.signs});

  factory TranslationResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> signsJson = json['signs'] as List<dynamic>;
    final signs = signsJson.map((signJson) => Sign.fromJson(signJson)).toList();
    
    return TranslationResponse(signs: signs);
  }
} 