import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'speech_screen.dart';
import '../widgets/landmark_painter.dart'; // Import the custom painter
import 'package:http/http.dart' as http; // Import http package
import 'dart:convert'; // Import for JSON decoding
import 'dart:async'; // Import for Timer
import 'dart:io'; // Needed for Platform

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

// import '../widgets/sign_video_player.dart'; // No longer using video player directly
import '../models/translation_response.dart';
import '../services/translation_service.dart';
import '../controllers/sign_animation_controller.dart';

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
  SignAnimationController _controller = SignAnimationController();

  @override
  void initState() {
    super.initState();
    print('SignDisplayScreen initialized with text: ${widget.textToTranslate}, sourceLanguage: ${widget.sourceLanguage}');
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadEnvironmentVariables();
    await _fetchTranslationData();
  }

  Future<void> _loadEnvironmentVariables() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      print('Error loading .env file: $e');
      // Continue without env file - will use defaults
    }
  }

  Future<void> _fetchTranslationData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final fps = int.tryParse(dotenv.env['ANIMATION_FPS'] ?? '30') ?? 30;
      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://127.0.0.1:8080'; // Get backend URL

      print('Fetching translation for text: ${widget.textToTranslate}, language: ${widget.sourceLanguage}');
      final response = await TranslationService.translateTextToSign(
        widget.textToTranslate,
        widget.sourceLanguage,
      );

      print('Translation response received with ${response.signs.length} signs');
      if (response.signs.isNotEmpty) {
        // Fetch landmark data for each sign
        final List<Sign> signsWithLandmarks = [];
        for (final sign in response.signs) {
          if (sign.mediaPath.isNotEmpty) {
            try {
              final landmarkData = await _fetchLandmarkData(backendUrl, sign.mediaPath);
              signsWithLandmarks.add(Sign(
                mediaPath: sign.mediaPath, // Keep original mediaPath if needed
                landmarkData: landmarkData,
              ));
            } catch (e) {
              print('Error fetching landmark data for ${sign.mediaPath}: $e');
              // Add sign without landmark data if fetching fails
              signsWithLandmarks.add(sign);
            }
          } else {
             // Add sign without landmark data if mediaPath is empty
            signsWithLandmarks.add(sign);
          }
        }

        if (signsWithLandmarks.any((sign) => sign.landmarkData != null)) {
           _controller.setSignData(signsWithLandmarks, fps: fps);
           _controller.startAnimation(); // Will only animate if appropriate
        } else {
           setState(() {
             _errorMessage = 'No landmark data available for animation.';
           });
           print('No landmark data available for animation.');
        }

      } else {
        setState(() {
          _errorMessage = 'No signs received for the translation.';
        });
        print('No signs received for the translation.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Translation error: $e';
      });
      print('Translation error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to fetch landmark data from backend
  Future<List<List<double>>> _fetchLandmarkData(String baseUrl, String mediaPath) async {
     // Extract the relative path from the full local path
     // Extract the path relative to the backend_python directory
     final mediaPathSegments = mediaPath.split(Platform.isWindows ? '\\' : '/');
     final backendDirIndex = mediaPathSegments.indexOf('backend_python');
     String relativePath = mediaPathSegments.sublist(backendDirIndex + 1).join('/');

     // Construct the full URL for the landmark data file
     final url = Uri.parse('$baseUrl/$relativePath');
     print('Fetching landmark data from: $url');

     final response = await http.get(url);

     if (response.statusCode == 200) {
       // Assuming the landmark data is a JSON array of arrays of doubles
       final List<dynamic> framesJson = jsonDecode(response.body) as List<dynamic>;
       final landmarkData = framesJson
           .map((frame) => (frame as List<dynamic>).cast<double>().toList())
           .toList();
       print('Successfully fetched and parsed landmark data.');
       return landmarkData;
     } else {
       print('Failed to fetch landmark data: ${response.statusCode} - ${response.body}');
       throw Exception('Failed to fetch landmark data: ${response.statusCode} - ${response.body}');
     }
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/images/signosi_logo_hand.png',
                height: 30, // Adjust height as needed
              ),
              const SizedBox(width: 8),
              const Text(
                'Signosi',
                style: TextStyle(color: Colors.deepOrange),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
            ),
          ],
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
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
            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
        bottomNavigationBar: _isLoading || _errorMessage.isNotEmpty
          ? _buildSimpleBottomBar()
          : _buildNavigationControls(),
      ),
    );
  }

  Widget _buildSimpleBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrangeAccent,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'Start again',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Consumer<SignAnimationController>(
      builder: (context, controller, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (controller.totalSigns > 1)
                ElevatedButton(
                  onPressed: controller.isFirstSign 
                    ? null 
                    : () => controller.previousSign(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Previous Sign'),
                ),
                
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrangeAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Start again',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              
              if (controller.totalSigns > 1)
                ElevatedButton(
                  onPressed: controller.isLastSign 
                    ? null 
                    : () => controller.nextSign(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Next Sign'),
                ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading sign translation...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<SignAnimationController>(
      builder: (context, controller, child) {
        final currentSign = controller.currentSign;

        if (currentSign == null) {
          return const Center(
            child: Text('No signs available for this text.'),
          );
        }

        // Check if landmark data is available
        if (currentSign.landmarkData != null && currentSign.landmarkData!.isNotEmpty) {
          // Use LandmarkPainter to render animation
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pass landmark data to a widget that uses LandmarkPainter
                // This assumes LandmarkPainter can be used directly or via a wrapper widget
                // that takes landmark data and animates it.
                // If SignAnimationController handles the animation state and provides
                // the current frame's landmarks, we might need a different approach.
                // For now, assuming LandmarkPainter needs the full data and controller
                // manages the animation progress.
                Expanded(
                   child: CustomPaint(
                     painter: LandmarkPainter(
                       landmarkData: controller.currentFrameLandmarks, // Use the getter
                       numberOfPoseLandmarks: 33, // Assuming 33 pose landmarks
                       numberOfHandLandmarks: 21, // Assuming 21 hand landmarks per hand (total 42 for two hands, but painter expects per hand?) - Let's assume 21 per hand for now based on typical MediaPipe output structure
                       isWorldLandmarks: false, // Assuming 2D image landmarks
                     ),
                     child: Container(), // Empty container as child
                   ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign ${controller.currentSignIndex + 1} of ${controller.totalSigns}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Animating from landmark data',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                 const SizedBox(height: 16),
                 ElevatedButton.icon(
                   onPressed: () {
                     controller.restartCurrentSign();
                   },
                   icon: const Icon(Icons.refresh),
                   label: const Text('Play Again'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.orangeAccent,
                     foregroundColor: Colors.white,
                   ),
                 ),
              ],
            ),
          );
        } else {
          // If no landmark data, display media path or a placeholder
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sign_language, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'No landmark data available for animation.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Media path: ${currentSign.mediaPath}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Maybe retry fetching or indicate the issue
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  // Removed _checkFileExists and _buildVideoPlayer as they are no longer used
  // Removed _buildMediaPathDisplay as its logic is integrated into _buildMainContent
}
