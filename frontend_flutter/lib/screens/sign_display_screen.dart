import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'speech_screen.dart';
import '../widgets/landmark_painter.dart'; // Import the custom painter
import 'package:http/http.dart' as http; // Import http package
import 'dart:convert'; // Import for JSON decoding
import 'dart:async'; // Import for Timer

import 'package:flutter_dotenv/flutter_dotenv.dart';

class SignDisplayScreen extends StatefulWidget {
  final String textToTranslate; // Text received from SpeechScreen

  const SignDisplayScreen({Key? key, required this.textToTranslate}) : super(key: key);

  @override
  _SignDisplayScreenState createState() => _SignDisplayScreenState();
}

class _SignDisplayScreenState extends State<SignDisplayScreen> with SingleTickerProviderStateMixin {
  List<List<double>> _landmarkFrames = []; // List of landmark data for each frame
  int _currentFrameIndex = 0;
  Timer? _animationTimer;
  bool _isLoading = true;
  String _errorMessage = '';

  // Define the number of landmarks based on MediaPipe (adjust if backend output differs)
  final int _numberOfPoseLandmarks = 33;
  final int _numberOfHandLandmarks = 21; // Per hand

  @override
  void initState() {
    super.initState();
    _loadEnvironmentVariables();
    _fetchLandmarkData();
  }

  Future<void> _loadEnvironmentVariables() async {
    await dotenv.load(fileName: ".env");
  }

  Future<void> _fetchLandmarkData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final String backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://127.0.0.1:8080';
    const String translateEndpoint = '/translate-text-to-slsl';

    try {
      final response = await http.post(
        Uri.parse('$backendUrl$translateEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': widget.textToTranslate, 'source_language': 'si'}), // Assuming Sinhala for now
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['landmark_data'] is List) {
          _landmarkFrames = (data['landmark_data'] as List)
              .map((frame) => (frame as List).cast<double>())
              .toList();
          if (_landmarkFrames.isNotEmpty) {
            _startAnimation();
          } else {
            setState(() {
              _errorMessage = 'No landmark data received for the translation.';
            });
          }
        } else {
          setState(() {
            _errorMessage = 'Invalid data format received from the backend.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error from backend: ${response.statusCode} - ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect to backend or fetch data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startAnimation() {
    final int fps = int.tryParse(dotenv.env['ANIMATION_FPS'] ?? '30') ?? 30;
    final Duration frameDuration = Duration(milliseconds: 1000 ~/ fps);

    _animationTimer = Timer.periodic(frameDuration, (timer) {
      if (_currentFrameIndex < _landmarkFrames.length - 1) {
        setState(() {
          _currentFrameIndex++;
        });
      } else {
        _animationTimer?.cancel(); // Stop animation at the end
        // Optionally loop animation:
        // setState(() {
        //   _currentFrameIndex = 0;
        // });
      }
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator() // Show loading indicator
            : _errorMessage.isNotEmpty
                ? Text(_errorMessage) // Show error message
                : _landmarkFrames.isEmpty
                    ? const Text('No animation data available.') // Handle empty data
                    : Center( // Center the animation within the AspectRatio
                        child: AspectRatio(
                          aspectRatio: 1.0, // Adjust aspect ratio as needed
                          child: CustomPaint(
                            painter: LandmarkPainter(
                              landmarkData: _landmarkFrames[_currentFrameIndex],
                              numberOfPoseLandmarks: _numberOfPoseLandmarks,
                              numberOfHandLandmarks: _numberOfHandLandmarks,
                              isWorldLandmarks: false, // Assuming image landmarks for 2D drawing
                            ),
                          ),
                        ),
                      ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Navigate back to the previous screen (SpeechScreen)
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
      ),
    );
  }
}
