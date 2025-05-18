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
  bool _useTestData = true; // Added for testing

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

    if (_useTestData) {
      print('Using test landmark data from April_001.csv');

      // Raw CSV data for the first two frames
      const String csvFrame1 = """"[0.3719269931316376, 0.4031713306903839, -0.5908280611038208, 0.9998818635940552]","[0.3896176815032959, 0.38208091259002686, -0.5638502836227417, 0.9998152852058411]","[0.39731135964393616, 0.38296976685523987, -0.5638006329536438, 0.999832272529602]","[0.40733739733695984, 0.3846631944179535, -0.5637032389640808, 0.9998132586479187]","[0.35938969254493713, 0.3815893828868866, -0.5601824522018433, 0.9998539686203003]","[0.3485001027584076, 0.38251930475234985, -0.5601455569267273, 0.9998506307601929]","[0.3394871950149536, 0.3841092586517334, -0.5603248476982117, 0.9998290538787842]","[0.4226909875869751, 0.39998435974121094, -0.3606184124946594, 0.9998621940612793]","[0.325337678194046, 0.39873406291007996, -0.33377805352211, 0.9998039603233337]","[0.3887314796447754, 0.43392863869667053, -0.51450115442276, 0.9999582767486572]","[0.3524875044822693, 0.43407633900642395, -0.5072373151779175, 0.9999469518661499]","[0.49294668436050415, 0.545862078666687, -0.2524036467075348, 0.9999659061431885]","[0.2443741112947464, 0.5384296178817749, -0.1646309643983841, 0.999947190284729]","[0.5498917698860168, 0.7352914214134216, -0.37451353669166565, 0.9939180612564087]","[0.16002751886844635, 0.7537338733673096, -0.3655508756637573, 0.9944643378257751]","[0.4364374577999115, 0.6767564415931702, -0.7040620446205139, 0.9913852214813232]","[0.2360420823097229, 0.6580294370651245, -0.875379204750061, 0.9946960210800171]","[0.39671769738197327, 0.6778639554977417, -0.7753905653953552, 0.9572309255599976]","[0.2601676881313324, 0.6356126070022583, -0.9613609313964844, 0.9759569764137268]","[0.389016717672348, 0.6517277956008911, -0.7475535869598389, 0.9564473032951355]","[0.2599497437477112, 0.6063519716262817, -0.9468079209327698, 0.9727716445922852]","[0.3956421911716461, 0.6506086587905884, -0.6948451399803162, 0.9573090076446533]","[0.2612255811691284, 0.6111517548561096, -0.8783161640167236, 0.9727998971939087]","[0.4344797730445862, 0.8344051241874695, -0.02142213098704815, 0.793832540512085]","[0.2656612992286682, 0.8371866941452026, 0.023558832705020905, 0.8300541043281555]","[0.4275031089782715, 1.0698153972625732, 0.0697617307305336, 0.003622946795076132]","[0.2514631450176239, 1.0712993144989014, 0.24166043102741241, 0.002160710282623768]","[0.39997807145118713, 1.2802903652191162, 0.43927690386772156, 0.0002180249139200896]","[0.24404728412628174, 1.2903709411621094, 0.5913673043251038, 0.00015706305566709489]","[0.3986496925354004, 1.3114383220672607, 0.4634665846824646, 0.0008348491392098367]","[0.24144327640533447, 1.3266106843948364, 0.615894079208374, 0.0003225167456548661]","[0.38323792815208435, 1.3598363399505615, 0.19609718024730682, 0.00019037030870094895]","[0.2464931756258011, 1.36416494846344, 0.32593101263046265, 0.0004652292700484395]""";
      const String csvFrame2 = """"[0.37064114212989807, 0.40311992168426514, -0.6227223873138428, 0.9998902678489685]","[0.38886213302612305, 0.38190725445747375, -0.588924765586853, 0.9998291730880737]","[0.3972688913345337, 0.3828850984573364, -0.5888422131538391, 0.999844491481781]","[0.4064840078353882, 0.38460099697113037, -0.5886795520782471, 0.9998267292976379]","[0.3582955598831177, 0.38133203983306885, -0.5827250480651855, 0.9998639225959778]","[0.34758955240249634, 0.3823230564594269, -0.5826057195663452, 0.9998601078987122]","[0.3384356200695038, 0.383775532245636, -0.5826959013938904, 0.9998393654823303]","[0.4223119914531708, 0.40029194951057434, -0.3587500751018524, 0.9998728632926941]","[0.32511767745018005, 0.39857611060142517, -0.3241611123085022, 0.9998170137405396]","[0.38842999935150146, 0.43380215764045715, -0.533801257610321, 0.9999614357948303]","[0.3505769670009613, 0.4329037070274353, -0.5238711833953857, 0.999950647354126]","[0.49284645915031433, 0.5458669066429138, -0.2488323599100113, 0.9999672174453735]","[0.24352391064167023, 0.5399615168571472, -0.1446349173784256, 0.9999465346336365]","[0.5511842370033264, 0.7366482019424438, -0.46656614542007446, 0.9942821860313416]","[0.15920226275920868, 0.753070592880249, -0.42614108324050903, 0.9944739937782288]","[0.4381239116191864, 0.6615561246871948, -0.8738317489624023, 0.9919893741607666]","[0.2349618375301361, 0.6399224400520325, -1.0411443710327148, 0.9948210716247559]","[0.3962463438510895, 0.6516651511192322, -0.9599170684814453, 0.9596949815750122]","[0.26002827286720276, 0.6123390793800354, -1.1429208517074585, 0.9761415719985962]","[0.3890363574028015, 0.6252772808074951, -0.914014995098114, 0.9589480757713318]","[0.2600816786289215, 0.5838589072227478, -1.117103934288025, 0.9729586839675903]","[0.39600953459739685, 0.6263655424118042, -0.8594611287117004, 0.9596051573753357]","[0.261079877614975, 0.5908504128456116, -1.0431567430496216, 0.9730006456375122]","[0.4347246289253235, 0.8388091325759888, -0.023468803614377975, 0.79680335521698]","[0.26340994238853455, 0.839028000831604, 0.02575131133198738, 0.8325176239013672]","[0.4328649938106537, 1.093834638595581, 0.11864227056503296, 0.003815529402345419]","[0.252480149269104, 1.0917242765426636, 0.25936242938041687, 0.002341938205063343]","[0.4132389724254608, 1.3062041997909546, 0.5761498212814331, 0.00021727883722633123]","[0.25375598669052124, 1.3151603937149048, 0.6671398282051086, 0.00015571183757856488]","[0.41246461868286133, 1.3408722877502441, 0.6066835522651672, 0.0008453560876660049]","[0.25345954298973083, 1.355647087097168, 0.6961130499839783, 0.00032595390803180635]","[0.4019602835178375, 1.3892453908920288, 0.30823713541030884, 0.00018682860536500812]","[0.2529415190219879, 1.3923066854476929, 0.3642551004886627, 0.0004705738683696836]""";

      List<Sign> testSigns = [];
      List<String> csvFrames = [csvFrame1, csvFrame2];

      for (String csvFrameData in csvFrames) {
        List<double> landmarks = [];
        // Split by '","' to separate landmark entries, then remove leading/trailing quotes from the whole string
        List<String> landmarkEntries = csvFrameData.substring(1, csvFrameData.length -1).split('","');

        for (String entry in landmarkEntries) {
          // Remove '[' and ']' and then split by ', '
          List<String> valuesStr = entry.replaceAll('[', '').replaceAll(']', '').split(', ');
          if (valuesStr.length == 4) { // x, y, z, visibility
            landmarks.add(double.parse(valuesStr[0])); // x
            landmarks.add(double.parse(valuesStr[1])); // y
            landmarks.add(double.parse(valuesStr[2])); // z
            landmarks.add(double.parse(valuesStr[3])); // visibility
            landmarks.add(1.0); // presence (assuming 1.0 as it's pose data)
          }
        }
        if (landmarks.isNotEmpty) {
          // The CSV contains 33 pose landmarks. Each has 4 values. We add a 5th (presence).
          // So, 33 * 5 = 165 doubles per frame.
          if (landmarks.length == 165) {
             testSigns.add(Sign(mediaPath: "test_csv_sign", landmarkData: [landmarks]));
          } else {
            print("Warning: Parsed frame data length is ${landmarks.length}, expected 165. Skipping frame.");
          }
        }
      }

      if (testSigns.isNotEmpty) {
        final fps = int.tryParse(dotenv.env['ANIMATION_FPS'] ?? '30') ?? 30;
        _controller.setSignData(testSigns, fps: fps);
        _controller.startAnimation();
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

    if (_useTestData && _controller.signs.isNotEmpty && _controller.signs[0].landmarkData != null && _controller.signs[0].landmarkData!.isNotEmpty) {
       print("Displaying test data with LandmarkPainter");
      return CustomPaint(
        painter: LandmarkPainter(
          landmarkData: _controller.signs[0].landmarkData![0], // Display first frame of first sign
          numberOfPoseLandmarks: 33, // From CSV
          numberOfHandLandmarks: 0,  // No hand data in this CSV
          isWorldLandmarks: false, // CSV data is likely 2D screen coordinates
        ),
        child: Container(),
      );
    } else if (!_useTestData && _controller.signs.isNotEmpty && _controller.signs[0].landmarkData != null && _controller.signs[0].landmarkData!.isNotEmpty) {
      return CustomPaint(
        painter: LandmarkPainter(
          landmarkData: _controller.currentFrameLandmarks,
          numberOfPoseLandmarks: 33, 
          numberOfHandLandmarks: 21, 
          isWorldLandmarks: false, // Assuming screen coordinates for fetched data too for now
        ),
        child: Container(),
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
