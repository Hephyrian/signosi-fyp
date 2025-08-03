import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'profile_screen.dart';
import 'speech_screen.dart';
import '../widgets/landmark_painter.dart'; // Import the custom painter
import '../widgets/app_navigation_bar.dart';
import 'package:http/http.dart' as http; // Import http package
import 'dart:convert'; // Import for JSON decoding
import 'dart:async'; // Import for Timer
import 'dart:io'; // Needed for Platform
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart'; // Added for video playback
import '../models/translation_response.dart';
import '../services/translation_service.dart';
import '../controllers/sign_animation_controller.dart';
import '../services/theme_provider.dart';

class SignDisplayScreen extends StatefulWidget {
  final String textToTranslate;
  final String sourceLanguage;

  const SignDisplayScreen({
    Key? key, 
    required this.textToTranslate,
    this.sourceLanguage = 'si',  // Default to Sinhala if not specified
  }) : super(key: key);

  @override
  _SignDisplayScreenState createState() => _SignDisplayScreenState();
}

class _SignDisplayScreenState extends State<SignDisplayScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  final SignAnimationController _controller = SignAnimationController(); // Final for field initializer
  bool _useTestData = false; // Default to false to allow video playback path

  // Sequential Playback State
  List<Sign> _allSigns = [];
  int _currentSignIndex = 0;

  // Video Player State for the current sign
  VideoPlayerController? _activeVideoPlayerController;
  Future<void>? _initializeActiveVideoPlayerFuture;
  bool _isShowingVideoContent = false; // To determine if current sign should display video or landmark

  // FPS for animation - loaded from .env (reduced for better visibility)
  int _animationFps = 12;

  // Test data from Bad_001_hand_landmarks.csv (Right hand, 21 landmarks per frame)
  // Frame 0
  static const String csvBadFrame1 = """"[0.7548737525939941,0.5932378768920898,-3.635961434156343e-07,0.0]","[0.728845477104187,0.5761290788650513,0.0032729096710681915,0.0]","[0.715084433555603,0.558305025100708,0.0030686177778989077,0.0]","[0.7072984576225281,0.5422724485397339,-0.0013074843445792794,0.0]","[0.7062391638755798,0.5268468856811523,-0.005446325056254864,0.0]","[0.7329219579696655,0.5339693427085876,0.01573677361011505,0.0]","[0.7192139625549316,0.523029088973999,0.007404610048979521,0.0]","[0.7122801542282104,0.5353289842605591,0.00014754783478565514,0.0]","[0.7106570601463318,0.5500458478927612,-0.0020610035862773657,0.0]","[0.7386649250984192,0.5318588018417358,0.009044624865055084,0.0]","[0.720899760723114,0.5235512852668762,-0.0023777929600328207,0.0]","[0.715600848197937,0.5403869152069092,-0.01119239255785942,0.0]","[0.7151370048522949,0.5556443929672241,-0.013652714900672436,0.0]","[0.745735764503479,0.5294637084007263,0.001012205146253109,0.0]","[0.7271649837493896,0.5202445983886719,-0.010941635817289352,0.0]","[0.7217717170715332,0.5371203422546387,-0.015221502631902695,0.0]","[0.7225801944732666,0.5522609949111938,-0.013288394547998905,0.0]","[0.7524570226669312,0.5272709727287292,-0.006695352029055357,0.0]","[0.7432875633239746,0.5045188069343567,-0.010270248167216778,0.0]","[0.7355450391769409,0.4918433725833893,-0.008838123641908169,0.0]","[0.7293587327003479,0.4813601076602936,-0.00581545103341341,0.0]""";
  // Frame 1
  static const String csvBadFrame2 = """"[0.7510221600532532,0.5882725715637207,-2.48390222168382e-07,0.0]","[0.7264186143875122,0.5732042789459229,0.003378016874194145,0.0]","[0.7134166359901428,0.5555407404899597,0.00458280136808753,0.0]","[0.7065786123275757,0.5396603345870972,0.001744197797961533,0.0]","[0.7064195275306702,0.5245199203491211,-0.0005724576767534018,0.0]","[0.7256267666816711,0.5332132577896118,0.017957182601094246,0.0]","[0.7161718606948853,0.5201088190078735,0.00948240701109171,0.0]","[0.7105217576026917,0.5323400497436523,0.0029568730387836695,0.0]","[0.7098551988601685,0.5464351177215576,0.0016644778661429882,0.0]","[0.7322190403938293,0.5307217836380005,0.012136191129684448,0.0]","[0.7193277478218079,0.5188592076301575,0.0006168438121676445,0.0]","[0.7146736979484558,0.5352380871772766,-0.007454841397702694,0.0]","[0.7149906158447266,0.5502008199691772,-0.008520454168319702,0.0]","[0.7413644194602966,0.5282655954360962,0.004761312156915665,0.0]","[0.7264914512634277,0.5187584161758423,-0.0066305468790233135,0.0]","[0.7216036319732666,0.5355955958366394,-0.009918500669300556,0.0]","[0.7230018377304077,0.5496034622192383,-0.006651936564594507,0.0]","[0.7509673833847046,0.52628493309021,-0.0024045195896178484,0.0]","[0.7444785833358765,0.5032973289489746,-0.006168593652546406,0.0]","[0.7381910085678101,0.4901561737060547,-0.005302421748638153,0.0]","[0.7331218719482422,0.4791611433029175,-0.002117812866345048,0.0]""";

  @override
  void initState() {
    super.initState();
    final timestamp = DateTime.now().toIso8601String();
    print('📱 [$timestamp] SignDisplayScreen initialized with text: "${widget.textToTranslate}", sourceLanguage: "${widget.sourceLanguage}"');
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadEnvironmentVariables();
    _animationFps = 12; // Force to 12 fps for slower, more viewable animations
    print('🎯 Animation FPS forced to: $_animationFps');
    
    // Check if running on emulator and warn about video playback issues
    if (_isRunningOnEmulator()) {
      print('⚠️  Running on Android emulator detected!');
      print('💡 Video playback may fail due to emulator limitations.');
      print('🔧 For best results, test on a physical Android device.');
    }
    
    // Test with public video to diagnose ExoPlayer issues
    _testWithPublicVideo();
    
    await _fetchTranslationAndPlay();
  }

  Future<void> _loadEnvironmentVariables() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      print('Error loading .env file: $e');
      // Continue without env file - will use defaults
    }
  }

  Future<void> _fetchTranslationAndPlay() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _isShowingVideoContent = false;
      _allSigns.clear();
      _currentSignIndex = 0;
    });

    // Dispose previous video controller if any and reset animation controller
    await _activeVideoPlayerController?.dispose();
    _activeVideoPlayerController = null;
    _initializeActiveVideoPlayerFuture = null;
    _controller.stopAnimation();
    _controller.clearData();

    if (_useTestData) {
      _setupTestDataAndPlay();
      return;
    }

    try {
      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://127.0.0.1:8080';
      final timestamp = DateTime.now().toIso8601String();
      print('🔄 [$timestamp] SignDisplayScreen: Initiating translation request');
      print('📝 Text: "${widget.textToTranslate}", Language: "${widget.sourceLanguage}", Backend: "$backendUrl"');
      
      final response = await TranslationService.translateTextToSign(
        widget.textToTranslate,
        widget.sourceLanguage,
        baseUrl: backendUrl, // Pass baseUrl if your service needs it
      );

      final responseTimestamp = DateTime.now().toIso8601String();
      print('✅ [$responseTimestamp] SignDisplayScreen: Translation response received with ${response.signs.length} signs');
      
      if (response.signs.isNotEmpty) {
        print('📋 Signs received:');
        for (int i = 0; i < response.signs.length; i++) {
          final sign = response.signs[i];
          print('  [$i] Label: "${sign.label}", VideoPath: "${sign.videoPath}", AnimationPath: "${sign.animationPath}"');
        }
        _allSigns = response.signs;
        _playSignAtIndex(_currentSignIndex); // This will eventually set _isLoading = false
      } else {
        setState(() {
          _errorMessage = 'No signs received for the translation.';
          _isLoading = false;
        });
        print('⚠️ No signs received for the translation.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Translation error: $e';
        _isLoading = false;
      });
      final errorTimestamp = DateTime.now().toIso8601String();
      print('❌ [$errorTimestamp] SignDisplayScreen: Translation error: $e');
    }
  }

  void _setupTestDataAndPlay() {
    print('Using test landmark data from Bad_001_hand_landmarks.csv');
    List<Sign> testDataSigns = [];
    List<String> csvFrames = [csvBadFrame1, csvBadFrame2];
    int expectedLandmarksPerFrame = 21;

    List<List<double>> signLandmarkFrames = [];
    for (String csvFrameData in csvFrames) {
      List<double> landmarks = [];
      // Robust parsing for CSV frame data
      try {
        List<String> landmarkEntries = csvFrameData
            .substring(1, csvFrameData.length - 1) // Remove outer quotes
            .split('","'); // Split by delimiter

        for (String entry in landmarkEntries) {
          List<String> valuesStr = entry.replaceAll('[', '').replaceAll(']', '').split(',');
          if (valuesStr.length == 4) { // x, y, z, visibility
            landmarks.add(double.parse(valuesStr[0].trim())); // x
            landmarks.add(double.parse(valuesStr[1].trim())); // y
            landmarks.add(double.parse(valuesStr[2].trim())); // z
            landmarks.add(double.parse(valuesStr[3].trim())); // visibility
            landmarks.add(1.0); // presence (assuming 1.0)
          }
        }
      } catch (e) {
        print("Error parsing CSV frame: $e. Frame data: $csvFrameData");
        continue; // Skip this frame if parsing fails
      }
      
      if (landmarks.isNotEmpty && landmarks.length == expectedLandmarksPerFrame * 5) {
        signLandmarkFrames.add(landmarks);
      } else {
        print("Warning: Parsed test frame data length is ${landmarks.length}, expected ${expectedLandmarksPerFrame * 5}. Skipping frame.");
      }
    }

    if (signLandmarkFrames.isNotEmpty) {
      testDataSigns.add(Sign(label: "test_csv_hand_sign", landmarkData: signLandmarkFrames, animationPath: "test_csv_hand_sign"));
      // Example: Add a second (dummy) sign for sequence testing
      // testDataSigns.add(Sign(mediaPath: "test_video_placeholder.mp4", mediaType: "video")); // requires a valid video for testing this path
    }
    
    if (testDataSigns.isNotEmpty) {
      _allSigns = testDataSigns;
      _playSignAtIndex(_currentSignIndex);
    } else {
      _errorMessage = "Failed to parse test CSV landmark data for sequential play.";
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playSignAtIndex(int index) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isShowingVideoContent = false;
      _errorMessage = ''; 
    });

    if (_activeVideoPlayerController != null) {
      _activeVideoPlayerController!.removeListener(_videoPlayerListener);
      await _activeVideoPlayerController!.dispose();
      _activeVideoPlayerController = null;
      _initializeActiveVideoPlayerFuture = null;
    }

    _controller.stopAnimation();
    _controller.clearData();
    _controller.onAnimationComplete = null;

    if (index < 0 || index >= _allSigns.length) {
      print('Index out of bounds or no signs to play. Index: $index, Total signs: ${_allSigns.length}');
      setState(() {
        _errorMessage = _allSigns.isEmpty ? "No signs to display." : "Reached end of signs.";
        _isLoading = false;
      });
      return;
    }

    _currentSignIndex = index;
    final Sign currentSign = _allSigns[_currentSignIndex];

    print('Playing sign at index $index: Path/ID: ${currentSign.label}');

    

    if (currentSign.videoPath != null) {
      setState(() { _isShowingVideoContent = true; });
      if (currentSign.videoPath == null || currentSign.videoPath!.isEmpty || !_isLikelyVideoUrl(currentSign.videoPath!)) {
          print('Video path is empty or not a valid URL for sign $index: ${currentSign.videoPath}');
          _errorMessage = 'Invalid video path for sign ${index + 1}.';
          _handleUnplayableSign();
          return;
      }
      try {
        // Enhanced debugging for video URL
        print('🎥 Attempting to load video for sign $index');
        print('🔗 Full URL: ${currentSign.videoPath}');
        print('🔍 URL Length: ${currentSign.videoPath!.length}');
        print('🌐 URL starts with HTTPS: ${currentSign.videoPath!.startsWith('https')}');
        
        final parsedUri = Uri.parse(currentSign.videoPath!);
        print('🏠 Host: ${parsedUri.host}');
        print('📁 Path: ${parsedUri.path}');
        print('❓ Query params count: ${parsedUri.queryParameters.length}');
        
        _activeVideoPlayerController = VideoPlayerController.networkUrl(parsedUri);
        _initializeActiveVideoPlayerFuture = _activeVideoPlayerController!.initialize().then((_) {
          if (!mounted) return;
          print('✅ Video player initialized successfully for sign $index');
          _activeVideoPlayerController!.play();
          _activeVideoPlayerController!.setLooping(false); // Ensure video does not loop
          _activeVideoPlayerController!.addListener(_videoPlayerListener);
          setState(() { _isLoading = false; });
        }).catchError((error) {
          if (!mounted) return;
          print('❌ Error initializing video player for sign $index: $error');
          print('🔗 Failed URL: ${currentSign.videoPath}');
          print('🔧 Error type: ${error.runtimeType}');
          if (error is PlatformException) {
            print('🔧 Platform Exception Code: ${error.code}');
            print('🔧 Platform Exception Message: ${error.message}');
            print('🔧 Platform Exception Details: ${error.details}');
          }
          _errorMessage = 'Failed to load video for sign ${index + 1}: $error';
          _handleUnplayableSign(); // This will set isLoading = false and attempt to advance
        });
      } catch (e) { // Catch synchronous errors from Uri.parse or VideoPlayerController constructor
         if (!mounted) return;
         print('Synchronous error setting up video player for sign $index: $e');
        _errorMessage = 'Error setting up video for sign ${index + 1}: $e';
        _handleUnplayableSign();
      }
    } else { 
        // Handle signs with landmark data (either pre-loaded or needs fetching)
        setState(() { _isShowingVideoContent = false; });
        List<List<double>>? landmarksToAnimate = currentSign.landmarkData;

        // If landmark data is null, try to fetch from landmark path
        if (landmarksToAnimate == null && currentSign.landmarkPath != null && currentSign.landmarkPath!.isNotEmpty) {
            try {
                print('🔄 Fetching landmark data for sign $index from: ${currentSign.landmarkPath}');
                
                if (currentSign.landmarkPath!.startsWith('http')) {
                    // It's a direct S3 URL, use it as-is
                    print('🌐 Fetching from S3 URL: ${currentSign.landmarkPath!.substring(0, 100)}...');
                    landmarksToAnimate = await _fetchLandmarkData('', currentSign.landmarkPath!);
                } else {
                    // It's a local file path, convert to API endpoint
                    final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://127.0.0.1:8080';
                    final filename = currentSign.landmarkPath!.split('/').last;
                    final landmarkUrl = '$backendUrl/api/translate/landmark-data/$filename';
                    
                    print('🌐 Fetching from landmark endpoint: $landmarkUrl');
                    landmarksToAnimate = await _fetchLandmarkData(backendUrl, landmarkUrl);
                }
            } catch (e) {
                print('❌ Failed to fetch landmark data for ${currentSign.label}: $e');
                _errorMessage = 'Failed to load landmark data for sign ${index + 1}.\nError: $e';
            }
        }
        
        // Also check animationPath for backward compatibility
        else if (landmarksToAnimate == null && 
            currentSign.animationPath != null && currentSign.animationPath!.isNotEmpty &&
            (currentSign.animationPath!.toLowerCase().endsWith('.json') || currentSign.animationPath!.startsWith('http'))) {
            try {
                print('🔄 Fetching landmark data from animationPath for sign $index: ${currentSign.animationPath}');
                final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://127.0.0.1:8080';
                landmarksToAnimate = await _fetchLandmarkData(backendUrl, currentSign.animationPath!);
            } catch (e) {
                print('❌ Failed to fetch remote landmark data for ${currentSign.label}: $e');
                _errorMessage = 'Failed to load landmark data for sign ${index + 1}.\nError: $e';
            }
        }

        if (landmarksToAnimate != null && landmarksToAnimate.isNotEmpty) {
            print('✅ Starting landmark animation for sign $index with ${landmarksToAnimate.length} frames');
            print('🎯 Passing FPS value to controller: $_animationFps');
            _controller.setSignData(
                [Sign(label: currentSign.label, landmarkData: landmarksToAnimate)],
                fps: _animationFps
            );
            _controller.onAnimationComplete = _advanceToNextSignAfterDelay;
            _controller.startAnimation();
            setState(() { _isLoading = false; });
        } else {
            print('❌ No landmark data available for sign $index (${currentSign.label})');
            _errorMessage = _errorMessage.isNotEmpty ? _errorMessage : 'No landmark data for animation for sign ${index + 1}.';
            _handleUnplayableSign();
        }
    }
  }
  
  void _handleUnplayableSign() {
    if (!mounted) return;
    setState(() {
        _isLoading = false; 
    });
    print("Unplayable sign encountered (Index: $_currentSignIndex). Error: $_errorMessage. Advancing after delay.");
            Future.delayed(const Duration(milliseconds: 2500), _advanceToNextSignAfterDelay);
  }

  void _videoPlayerListener() {
    if (!mounted || _activeVideoPlayerController == null || !_activeVideoPlayerController!.value.isInitialized) {
      return;
    }
    // It's important to check if the controller is still playing and the video has actually finished.
    // Sometimes, the listener might be called when the video is paused or at the very end multiple times.
    if (_activeVideoPlayerController!.value.isPlaying || _activeVideoPlayerController!.value.isBuffering) {
      return; // Don't advance if still playing or buffering
    }

    final position = _activeVideoPlayerController!.value.position;
    final duration = _activeVideoPlayerController!.value.duration;

    // Check if position is at or very near the end, and it's not already seeking.
    // Adding a small tolerance for floating point inaccuracies.
    if (duration > Duration.zero && (position >= duration || (duration - position).inMilliseconds < 100)) {
      print('Video for sign $_currentSignIndex finished. Position: $position, Duration: $duration');
      _activeVideoPlayerController!.removeListener(_videoPlayerListener); // Remove listener before advancing
      _advanceToNextSignAfterDelay();
    }
  }
  
  void _advanceToNextSignAfterDelay() {
    if (!mounted) return;
    // Adding a longer delay for better comprehension - gives users time to process the sign
    Future.delayed(const Duration(milliseconds: 2000), _advanceToNextSign);
  }

  void _advanceToNextSign() {
    if (!mounted) return;
    print('Attempting to advance from sign $_currentSignIndex. Total signs: ${_allSigns.length}');
    if (_currentSignIndex < _allSigns.length - 1) {
      final newIndex = _currentSignIndex + 1;
      print('Advancing to next sign: $newIndex');
      _playSignAtIndex(newIndex);
    } else {
      print('Reached the end of all signs.');
      setState(() {
        _errorMessage = "All signs played. You can start again or go back.";
        _isLoading = false; 
      });
    }
  }

  void _onPressedNext() {
    if (!mounted) return;
    print('Next button pressed. Current index: $_currentSignIndex, Total signs: ${_allSigns.length}');
    if (_currentSignIndex < _allSigns.length - 1 && !_isLoading) { // Prevent action while loading
      final newIndex = _currentSignIndex + 1;
      _playSignAtIndex(newIndex);
    } else {
      print('Next button: Already at the last sign or loading.');
    }
  }

  void _onPressedPrevious() {
    if (!mounted) return;
    print('Previous button pressed. Current index: $_currentSignIndex');
    if (_currentSignIndex > 0 && !_isLoading) { // Prevent action while loading
      final newIndex = _currentSignIndex - 1;
      _playSignAtIndex(newIndex);
    } else {
      print('Previous button: Already at the first sign or loading.');
    }
  }
  
  void _onRestartCurrentSign() {
    if (!mounted || _allSigns.isEmpty || _currentSignIndex >= _allSigns.length || _isLoading) return;

    print("Restarting current sign: $_currentSignIndex");
    // Re-trigger playing the current sign. _playSignAtIndex handles setup.
    _playSignAtIndex(_currentSignIndex);
  }

  bool _isLikelyVideoUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final Uri uri = Uri.parse(url);
      String path = uri.path;
      final lcPath = path.toLowerCase();
      return lcPath.endsWith('.mp4') || 
             lcPath.endsWith('.webm') || 
             lcPath.endsWith('.mov') || 
             lcPath.endsWith('.avi') ||
             lcPath.endsWith('.mkv') || // Added mkv
             lcPath.endsWith('.flv');  // Added flv
    } catch (e) {
      // If parsing fails, it's unlikely a valid URL for our purposes
      print("Error parsing URL in _isLikelyVideoUrl: $url - $e");
      return false;
    }
  }

  // Test method to try loading a known working video URL
  void _testWithPublicVideo() async {
    print('🧪 Testing with public video URL...');
    const testUrl = 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4';
    
    try {
      final testController = VideoPlayerController.networkUrl(Uri.parse(testUrl));
      await testController.initialize();
      print('✅ Public video loaded successfully!');
      testController.dispose();
    } catch (e) {
      print('❌ Public video also failed: $e');
      print('⚠️  This suggests ExoPlayer/emulator compatibility issues.');
      print('💡 Try running on a physical Android device instead of emulator.');
    }
  }

  // Check if running on emulator
  bool _isRunningOnEmulator() {
    return Platform.isAndroid && 
           (Platform.environment['ANDROID_EMULATOR'] == 'true' ||
            Platform.environment.containsKey('ANDROID_AVD_HOME'));
  }

  // Helper function to safely convert values to double
  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Function to fetch landmark data from backend
  Future<List<List<double>>> _fetchLandmarkData(String baseUrl, String mediaPath) async {
     // mediaPath is the S3 pre-signed URL that directly points to the landmark data (JSON).
     // We should fetch from this URL directly.

     final url = Uri.parse(mediaPath); // Use the S3 URL (mediaPath) directly
     final timestamp = DateTime.now().toIso8601String();
     print('🌐 [$timestamp] SignDisplayScreen: Fetching landmark data from: $url');

     try {
       final response = await http.get(url);
       final responseTimestamp = DateTime.now().toIso8601String();

             if (response.statusCode == 200) {
        print('✅ [$responseTimestamp] SignDisplayScreen: Landmark data fetch successful');
        print('📊 Response size: ${response.body.length} characters');
        
        // Safely parse the landmark data with better error handling
        try {
          final dynamic responseData = jsonDecode(response.body);
          
          if (responseData is List) {
            // Format 1: Simple array of frames [[x,y,z,vis,pres], ...]
            final List<dynamic> framesJson = responseData as List<dynamic>;
            final landmarkData = framesJson
                .map((frame) {
                  if (frame is List) {
                    return (frame as List<dynamic>).cast<double>().toList();
                  } else {
                    print('⚠️ Expected frame to be a List, but got: ${frame.runtimeType}');
                    return <double>[]; // Return empty list for invalid frames
                  }
                })
                .where((frame) => frame.isNotEmpty) // Filter out empty frames
                .toList();
            
            print('📈 Parsed ${landmarkData.length} frames of landmark data (simple format)');
            if (landmarkData.isNotEmpty) {
              print('📏 First frame has ${landmarkData[0].length} landmark coordinates');
            }
            
            return landmarkData;
          } else if (responseData is Map) {
            // Format 2: MediaPipe structure with frames array
            print('📊 Detected MediaPipe landmark format');
            final Map<String, dynamic> data = responseData as Map<String, dynamic>;
            
            if (data.containsKey('frames') && data['frames'] is List) {
              final List<dynamic> frames = data['frames'] as List<dynamic>;
              final List<List<double>> landmarkData = [];
              
              for (final frame in frames) {
                if (frame is Map) {
                  final Map<String, dynamic> frameData = frame as Map<String, dynamic>;
                  
                  // Extract hand landmarks (prioritize right hand, fallback to left hand)
                  List<dynamic>? handLandmarks = frameData['right_hand_landmarks'];
                  if (handLandmarks == null || handLandmarks.isEmpty) {
                    handLandmarks = frameData['left_hand_landmarks'];
                  }
                  
                  if (handLandmarks != null && handLandmarks is List && handLandmarks.isNotEmpty) {
                    // Convert landmarks to flat double array
                    final List<double> frameCoords = [];
                    for (final landmark in handLandmarks) {
                      if (landmark is Map) {
                        final x = _toDouble(landmark['x'] ?? 0.0);
                        final y = _toDouble(landmark['y'] ?? 0.0);
                        final z = _toDouble(landmark['z'] ?? 0.0);
                        final visibility = _toDouble(landmark['visibility'] ?? 1.0);
                        final presence = _toDouble(landmark['presence'] ?? 1.0);
                        
                        frameCoords.addAll([x, y, z, visibility, presence]);
                      }
                    }
                    
                    if (frameCoords.isNotEmpty) {
                      landmarkData.add(frameCoords);
                    }
                  }
                }
              }
              
              print('📈 Parsed ${landmarkData.length} frames from MediaPipe format');
              if (landmarkData.isNotEmpty) {
                print('📏 First frame has ${landmarkData[0].length} landmark coordinates');
              }
              
              return landmarkData;
            } else {
              throw Exception('MediaPipe format missing frames array');
            }
          } else {
            final errorMsg = 'Expected landmark data to be a List or Map, but got: ${responseData.runtimeType}';
            print('❌ $errorMsg');
            print('📄 Response data: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
            throw Exception(errorMsg);
          }
        } catch (e) {
          final errorMsg = 'Failed to parse landmark data JSON: $e';
          print('❌ $errorMsg');
          print('📄 Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
          throw Exception(errorMsg);
        }
       } else {
         final errorMsg = 'Failed to fetch landmark data: ${response.statusCode} - ${response.body}';
         print('❌ [$responseTimestamp] SignDisplayScreen: $errorMsg');
         throw Exception(errorMsg);
       }
     } catch (e) {
       final errorTimestamp = DateTime.now().toIso8601String();
       print('❌ [$errorTimestamp] SignDisplayScreen: Exception fetching landmark data: $e');
       rethrow;
     }
  }

  @override
  void dispose() {
    _activeVideoPlayerController?.removeListener(_videoPlayerListener);
    _activeVideoPlayerController?.dispose();
    _controller.onAnimationComplete = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        appBar: AppNavigationBar(
          activeScreen: 'sign',
          isDarkMode: themeProvider.isDarkMode,
          onToggleTheme: () => themeProvider.toggleTheme(),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.textToTranslate,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            if (_allSigns.isNotEmpty && _currentSignIndex < _allSigns.length && !_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Sign ${(_currentSignIndex + 1).toString()} of ${_allSigns.length.toString()}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomControls(),
      ),
    );
  }

  Widget _buildBottomControls() {
    // Simplified: always show controls if not in initial full load. Content handles specific states.
    if (_isLoading && _allSigns.isEmpty) { 
        return const SizedBox.shrink(); 
    }

    bool isAtEndAndFinished = _currentSignIndex >= _allSigns.length - 1 && 
                               _errorMessage == "All signs played. You can start again or go back.";
    
    if (isAtEndAndFinished || (_allSigns.isEmpty && _errorMessage.isNotEmpty)) {
         return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
                onPressed: () {
                    Navigator.pop(context); 
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrangeAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Start again', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
        );
    }

    return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
                ElevatedButton(
                    onPressed: (_currentSignIndex > 0 && !_isLoading) ? _onPressedPrevious : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Previous'),
                ),
                ElevatedButton(
                    onPressed: (_allSigns.isNotEmpty && !_isLoading) ? _onRestartCurrentSign : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Icon(Icons.replay),
                ),
                ElevatedButton(
                    onPressed: (_currentSignIndex < _allSigns.length - 1 && !_isLoading) ? _onPressedNext : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Next'),
                ),
            ],
        ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Prioritize error message if it's set and significant (not just "all signs played" unless that's the final state)
    if (_errorMessage.isNotEmpty && 
        !(_allSigns.isNotEmpty && _currentSignIndex < _allSigns.length) &&
        _errorMessage != "All signs played. You can start again or go back.") {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
      ));
    }
    
    if (_allSigns.isEmpty) {
      return Center(child: Text(_errorMessage.isNotEmpty ? _errorMessage : "No signs available for this translation.", 
                                  style: TextStyle(color: _errorMessage.isNotEmpty ? Colors.red : Colors.grey, fontSize: 16), 
                                  textAlign: TextAlign.center));
    }
    
    if (_currentSignIndex >= _allSigns.length) { // End of signs reached
         return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_errorMessage.isNotEmpty ? _errorMessage :"All signs have been played.", 
                        style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
        ));
    }

    final Sign currentSign = _allSigns[_currentSignIndex];

    if (_isShowingVideoContent && _activeVideoPlayerController != null && _initializeActiveVideoPlayerFuture != null) {
      return FutureBuilder(
        future: _initializeActiveVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (_activeVideoPlayerController!.value.isInitialized) {
              return Center(
                child: AspectRatio(
                  aspectRatio: _activeVideoPlayerController!.value.aspectRatio,
                  child: VideoPlayer(_activeVideoPlayerController!),
                ),
              );
            } else {
              // Video init failed, _errorMessage should have been set in _playSignAtIndex
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_errorMessage.isNotEmpty ? _errorMessage : "Error loading video: ${currentSign.label}", 
                            style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
              ));
            }
          }
          return const Center(child: CircularProgressIndicator()); // Still initializing
        },
      );
    } else if (!_isShowingVideoContent && 
               _controller.signs.isNotEmpty && // Check if controller has data for current landmark sign
               _controller.signs.first.landmarkData != null && 
               _controller.signs.first.landmarkData!.isNotEmpty) {
      return Consumer<SignAnimationController>(
          builder: (context, animController, child) {
              if (animController.currentFrameLandmarks.isEmpty && animController.isAnimating) {
                  // Handles brief moment before first frame is ready or if animation is stuck
                  return const Center(child: CircularProgressIndicator());
              }
              return CustomPaint(
                  painter: LandmarkPainter(
                  landmarkData: animController.currentFrameLandmarks,
                  numberOfPoseLandmarks: 0,
                  numberOfHandLandmarks: 21, // Assuming 21 hand landmarks for this data
                  isWorldLandmarks: false, 
                  ),
                  child: Container(),
              );
          }
      );
    }
    
    // Fallback for the current sign if it's unplayable or state is inconsistent
    return Center(child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        _errorMessage.isNotEmpty ? _errorMessage : 'Preparing content for sign ${currentSign.label}...',
        style: TextStyle(color: _errorMessage.isNotEmpty ? Colors.red : Colors.grey, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    ));
  }

  // Removed _checkFileExists and _buildVideoPlayer as they are no longer used
  // Removed _buildMediaPathDisplay as its logic is integrated into _buildMainContent
}
