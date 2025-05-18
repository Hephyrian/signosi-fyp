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
import 'package:video_player/video_player.dart'; // Added for video playback
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
  bool _useTestData = false; // Default to false to allow video playback path

  // Video Player State
  VideoPlayerController? _videoPlayerController;
  Future<void>? _initializeVideoPlayerFuture;
  bool _isShowingVideo = false;

  // Test data from Bad_001_hand_landmarks.csv (Right hand, 21 landmarks per frame)
  // Frame 0
  static const String csvBadFrame1 = """"[0.7548737525939941,0.5932378768920898,-3.635961434156343e-07,0.0]","[0.728845477104187,0.5761290788650513,0.0032729096710681915,0.0]","[0.715084433555603,0.558305025100708,0.0030686177778989077,0.0]","[0.7072984576225281,0.5422724485397339,-0.0013074843445792794,0.0]","[0.7062391638755798,0.5268468856811523,-0.005446325056254864,0.0]","[0.7329219579696655,0.5339693427085876,0.01573677361011505,0.0]","[0.7192139625549316,0.523029088973999,0.007404610048979521,0.0]","[0.7122801542282104,0.5353289842605591,0.00014754783478565514,0.0]","[0.7106570601463318,0.5500458478927612,-0.0020610035862773657,0.0]","[0.7386649250984192,0.5318588018417358,0.009044624865055084,0.0]","[0.720899760723114,0.5235512852668762,-0.0023777929600328207,0.0]","[0.715600848197937,0.5403869152069092,-0.01119239255785942,0.0]","[0.7151370048522949,0.5556443929672241,-0.013652714900672436,0.0]","[0.745735764503479,0.5294637084007263,0.001012205146253109,0.0]","[0.7271649837493896,0.5202445983886719,-0.010941635817289352,0.0]","[0.7217717170715332,0.5371203422546387,-0.015221502631902695,0.0]","[0.7225801944732666,0.5522609949111938,-0.013288394547998905,0.0]","[0.7524570226669312,0.5272709727287292,-0.006695352029055357,0.0]","[0.7432875633239746,0.5045188069343567,-0.010270248167216778,0.0]","[0.7355450391769409,0.4918433725833893,-0.008838123641908169,0.0]","[0.7293587327003479,0.4813601076602936,-0.00581545103341341,0.0]""";
  // Frame 1
  static const String csvBadFrame2 = """"[0.7510221600532532,0.5882725715637207,-2.48390222168382e-07,0.0]","[0.7264186143875122,0.5732042789459229,0.003378016874194145,0.0]","[0.7134166359901428,0.5555407404899597,0.00458280136808753,0.0]","[0.7065786123275757,0.5396603345870972,0.001744197797961533,0.0]","[0.7064195275306702,0.5245199203491211,-0.0005724576767534018,0.0]","[0.7256267666816711,0.5332132577896118,0.017957182601094246,0.0]","[0.7161718606948853,0.5201088190078735,0.00948240701109171,0.0]","[0.7105217576026917,0.5323400497436523,0.0029568730387836695,0.0]","[0.7098551988601685,0.5464351177215576,0.0016644778661429882,0.0]","[0.7322190403938293,0.5307217836380005,0.012136191129684448,0.0]","[0.7193277478218079,0.5188592076301575,0.0006168438121676445,0.0]","[0.7146736979484558,0.5352380871772766,-0.007454841397702694,0.0]","[0.7149906158447266,0.5502008199691772,-0.008520454168319702,0.0]","[0.7413644194602966,0.5282655954360962,0.004761312156915665,0.0]","[0.7264914512634277,0.5187584161758423,-0.0066305468790233135,0.0]","[0.7216036319732666,0.5355955958366394,-0.009918500669300556,0.0]","[0.7230018377304077,0.5496034622192383,-0.006651936564594507,0.0]","[0.7509673833847046,0.52628493309021,-0.0024045195896178484,0.0]","[0.7444785833358765,0.5032973289489746,-0.006168593652546406,0.0]","[0.7381910085678101,0.4901561737060547,-0.005302421748638153,0.0]","[0.7331218719482422,0.4791611433029175,-0.002117812866345048,0.0]""";

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
      _isShowingVideo = false; // Reset video state
    });
    // Dispose previous video controller if any
    await _videoPlayerController?.dispose();
    _videoPlayerController = null;
    _initializeVideoPlayerFuture = null;

    if (_useTestData) {
      print('Using test landmark data from Bad_001_hand_landmarks.csv');

      List<Sign> testSigns = [];
      // Using the new CSV data strings for Bad_001
      List<String> csvFrames = [csvBadFrame1, csvBadFrame2];
      int expectedLandmarksPerFrame = 21; // 21 hand landmarks

      for (String csvFrameData in csvFrames) {
        List<double> landmarks = [];
        List<String> landmarkEntries = csvFrameData.substring(1, csvFrameData.length -1).split('","');

        for (String entry in landmarkEntries) {
          List<String> valuesStr = entry.replaceAll('[', '').replaceAll(']', '').split(',');
          if (valuesStr.length == 4) { // x, y, z, visibility
            landmarks.add(double.parse(valuesStr[0])); // x
            landmarks.add(double.parse(valuesStr[1])); // y
            landmarks.add(double.parse(valuesStr[2])); // z
            landmarks.add(double.parse(valuesStr[3])); // visibility
            landmarks.add(1.0); // presence (assuming 1.0 as per original logic)
          }
        }
        if (landmarks.isNotEmpty) {
          // Each landmark has 5 values (x, y, z, visibility, presence).
          // For hand data, we have 21 landmarks. So, 21 * 5 = 105 doubles per frame.
          if (landmarks.length == expectedLandmarksPerFrame * 5) {
             testSigns.add(Sign(mediaPath: "test_csv_hand_sign", landmarkData: [landmarks]));
          } else {
            print("Warning: Parsed frame data length is ${landmarks.length}, expected ${expectedLandmarksPerFrame * 5}. Skipping frame.");
          }
        }
      }

      if (testSigns.isNotEmpty) {
        final fps = int.tryParse(dotenv.env['ANIMATION_FPS'] ?? '30') ?? 30;
        _controller.setSignData(testSigns, fps: fps);
        _controller.startAnimation();
        _isShowingVideo = false; // Ensure landmarks are shown for test data
      } else {
        _errorMessage = "Failed to parse test CSV landmark data.";
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

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
        final firstSign = response.signs.first;
        final String? signMediaType = firstSign.mediaType?.trim().toLowerCase(); // Null-safe, trim, lowercase
        
        print('Received first sign. Path: ${firstSign.mediaPath}, Raw mediaType: "${firstSign.mediaType}", Processed mediaType: "$signMediaType"');

        if (signMediaType == "video") {
          print('First sign mediaType is "video". Path: ${firstSign.mediaPath}');
          _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(firstSign.mediaPath));
          _initializeVideoPlayerFuture = _videoPlayerController!.initialize().then((_) {
            _videoPlayerController!.play();
            _videoPlayerController!.setLooping(true);
          }).catchError((error) {
            print('Error initializing video player: $error. Attempted URL: ${firstSign.mediaPath}');
            setState(() {
              if (mounted) {
                _errorMessage = 'Failed to load video: The content was not found on the server (Error 404).\nAttempted URL: ${firstSign.mediaPath}';
                _isShowingVideo = false;
              }
            });
          });
          setState(() {
            _isShowingVideo = true;
          });
        } else {
          print('First sign processed mediaType is not "video" (it is "$signMediaType"). Fetching landmarks if applicable.');
          _isShowingVideo = false;
          final List<Sign> signsWithLandmarks = [];
          for (final sign_iter in response.signs) { // Renamed to avoid conflict with outer scope 'sign' if any
            final String? currentSignMediaType = sign_iter.mediaType?.trim().toLowerCase(); // Null-safe, trim, lowercase
            
            print('Processing sign in loop. Path: ${sign_iter.mediaPath}, Raw mediaType: "${sign_iter.mediaType}", Processed mediaType: "$currentSignMediaType"');

            if (currentSignMediaType != "video" && sign_iter.mediaPath.isNotEmpty) {
              try {
                print('Attempting to fetch landmark data for sign with processed mediaType: "$currentSignMediaType", path: ${sign_iter.mediaPath}');
                final landmarkData = await _fetchLandmarkData(backendUrl, sign_iter.mediaPath);
                signsWithLandmarks.add(Sign(
                  mediaPath: sign_iter.mediaPath,
                  mediaType: sign_iter.mediaType, // Keep original mediaType for the object
                  landmarkData: landmarkData,
                ));
              } catch (e) {
                print('Error fetching landmark data for ${sign_iter.mediaPath}: $e');
                signsWithLandmarks.add(sign_iter);
              }
            } else {
              if (currentSignMediaType == "video") {
                print('Adding video sign to list without fetching landmarks: ${sign_iter.mediaPath}');
              }
              signsWithLandmarks.add(sign_iter);
            }
          }

          if (signsWithLandmarks.any((s) => s.landmarkData != null && s.landmarkData!.isNotEmpty)) {
             _controller.setSignData(signsWithLandmarks, fps: fps);
             _controller.startAnimation();
          } else if (!signsWithLandmarks.any((s) => s.mediaType?.trim().toLowerCase() == "video")) { 
             setState(() {
               _errorMessage = 'No landmark data available for animation, and no video found.';
             });
             print('No landmark data available for animation, and no video found.');
          }
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

  bool _isLikelyVideoUrl(String url) {
    final lcUrl = url.toLowerCase();
    return lcUrl.endsWith('.mp4') || lcUrl.endsWith('.webm') || lcUrl.endsWith('.mov') || lcUrl.endsWith('.avi');
    // Add more video extensions if needed, or use a more robust check
  }

  // Function to fetch landmark data from backend
  Future<List<List<double>>> _fetchLandmarkData(String baseUrl, String mediaPath) async {
     // mediaPath is the S3 pre-signed URL that directly points to the landmark data (JSON).
     // We should fetch from this URL directly.

     // OLD LOGIC (Incorrect):
     // final mediaPathSegments = mediaPath.split(Platform.isWindows ? '\' : '/');
     // final backendDirIndex = mediaPathSegments.indexOf('backend_python');
     // String relativePath = mediaPathSegments.sublist(backendDirIndex + 1).join('/');
     // final url = Uri.parse('$baseUrl/$relativePath');

     // CORRECTED LOGIC:
     final url = Uri.parse(mediaPath); // Use the S3 URL (mediaPath) directly
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
    _videoPlayerController?.dispose(); // Dispose video controller
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)));
    }

    // Video Player UI
    if (_isShowingVideo && _videoPlayerController != null && _initializeVideoPlayerFuture != null) {
      return FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && _videoPlayerController!.value.isInitialized) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: _videoPlayerController!.value.aspectRatio,
                    child: VideoPlayer(_videoPlayerController!),
                  ),
                  const SizedBox(height: 10),
                  IconButton(
                    icon: Icon(
                      _videoPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: () {
                      setState(() {
                        _videoPlayerController!.value.isPlaying
                            ? _videoPlayerController!.pause()
                            : _videoPlayerController!.play();
                      });
                    },
                  ),
                   Text(
                    'Playing video: ${_controller.currentSign?.mediaPath ?? ''}', // Display current sign's media path
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
             return Center(child: Text("Error loading video: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    }

    // Landmark Animation UI (Fallback or if _useTestData is true and it's landmark data)
    // This section is now secondary if video is available and chosen.
    if (_useTestData && _controller.signs.isNotEmpty && _controller.signs[0].landmarkData != null && _controller.signs[0].landmarkData!.isNotEmpty) {
       print("Displaying test data with LandmarkPainter");
      return CustomPaint(
        painter: LandmarkPainter(
          landmarkData: _controller.signs[0].landmarkData![0], // Display first frame of first sign
          numberOfPoseLandmarks: 0, // No pose landmarks in this test data
          numberOfHandLandmarks: 21,  // 21 hand landmarks
          isWorldLandmarks: false, // CSV data is likely 2D screen coordinates
        ),
        child: Container(),
      );
    } else if (!_useTestData && _controller.signs.isNotEmpty && _controller.signs[0].landmarkData != null && _controller.signs[0].landmarkData!.isNotEmpty) {
      return CustomPaint(
        painter: LandmarkPainter(
          landmarkData: _controller.currentFrameLandmarks,
          numberOfPoseLandmarks: 0, // Assuming no pose landmarks if primarily for sign language hands
          numberOfHandLandmarks: 21, // Assuming 21 hand landmarks per hand
          isWorldLandmarks: false, // Assuming 2D image landmarks
        ),
        child: Container(),
      );
    }

    // Consumer for Landmark Animation (if not showing video and landmarks are available)
    return Consumer<SignAnimationController>(
      builder: (context, controller, child) {
        final currentSign = controller.currentSign;

        if (currentSign == null) {
          return const Center(
            child: Text('No signs available for this text.'),
          );
        }

        // Check if landmark data is available FOR THE CURRENT SIGN
        // This is the "commented out" part - only shown if video is not the primary content for this screen.
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
                       numberOfPoseLandmarks: 0, // Assuming no pose landmarks if primarily for sign language hands
                       numberOfHandLandmarks: 21, // Assuming 21 hand landmarks per hand
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
          // If no landmark data for the current sign, display media path or a placeholder
          // This might also be hit if the sign was supposed to be a video but failed to load earlier
          // or if it's a non-video, non-landmark sign.
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off, size: 64, color: Colors.grey), // Changed icon
                const SizedBox(height: 16),
                Text(
                  _isLikelyVideoUrl(currentSign.mediaPath)
                    ? 'Video content not available or failed to load.'
                    : 'No landmark data available for animation.',
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
