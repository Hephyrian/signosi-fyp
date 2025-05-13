import 'package:flutter/material.dart';
import 'package:google_speech/google_speech.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../widgets/wave_animation.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'sign_display_screen.dart';

class SpeechScreen extends StatefulWidget {
  const SpeechScreen({super.key});

  @override
  State<SpeechScreen> createState() => _SpeechScreenState();
}

class _SpeechScreenState extends State<SpeechScreen> {
  bool _isSpeaking = false;
  String _transcribedText = '';
  bool _speechEnabled = false;
  double _soundLevel = 0.0;
  StreamSubscription<dynamic>? _subscription;
  SpeechToText? _speechToText;
  String _credentialsPath = '';
  late stt.SpeechToText _speech;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      print('Microphone permission granted');
      try {
        // Load Google Cloud credentials from assets or environment
        // Assuming credentials are stored in assets or a file
        // You may need to adjust this based on how credentials are managed in your app
        final directory = await getApplicationDocumentsDirectory();
        _credentialsPath = '${directory.path}/google-credentials.json';
        final credentialsData = await rootBundle.loadString('assets/google-credentials.json');
        await File(_credentialsPath).writeAsString(credentialsData);

        final serviceAccount = ServiceAccount.fromFile(File(_credentialsPath));
        _speechToText = SpeechToText.viaServiceAccount(serviceAccount);
        _speechEnabled = true;
        print('Google Speech-to-Text initialized successfully');
        
        // Initialize speech_to_text package
        _speech = stt.SpeechToText();
        bool available = await _speech.initialize(
          onStatus: (val) => print('onStatus: $val'),
          onError: (val) => print('onError: $val'),
        );
        if (available) {
          print('Speech to Text initialized successfully');
        } else {
          print('Speech to Text initialization failed');
          _speechEnabled = false;
          setState(() {
            _transcribedText = 'Failed to initialize speech recognition.';
          });
        }
      } catch (e) {
        print('Error initializing Google Speech-to-Text: $e');
        _speechEnabled = false;
        setState(() {
          _transcribedText = 'Failed to initialize speech recognition.';
        });
      }
      if (mounted) setState(() {});
    } else {
      print('Microphone permission denied');
      setState(() {
        _transcribedText = 'Microphone permission denied.';
      });
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) {
      await _initSpeech();
    }

    if (_speechEnabled && _speechToText != null) {
      setState(() {
        _isSpeaking = true;
        _transcribedText = '';
        _soundLevel = 0.0;
      });

      // Using speech_to_text package for audio streaming
      await _speech.listen(
        onResult: (val) => setState(() {
          _transcribedText = val.recognizedWords;
          print('Recognized text: $_transcribedText');
          if (val.hasConfidenceRating && val.confidence > 0) {
            _soundLevel = val.confidence * 100;
          }
        }),
        listenFor: const Duration(seconds: 30),
        localeId: 'si_LK', // Sinhala (Sri Lanka)
        onSoundLevelChange: (level) {
          setState(() {
            _soundLevel = level;
          });
        },
      );
    } else {
      setState(() {
        _transcribedText = 'Speech recognition failed to initialize or permission denied.';
      });
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() {
      _isSpeaking = false;
    });

    // Simulate processing time and navigate to SignDisplayScreen
    await Future.delayed(const Duration(seconds: 2)); // Adjust delay as needed

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SignDisplayScreen(textToTranslate: _transcribedText)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech to Text'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Transcribed text area
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                _transcribedText.isEmpty 
                  ? _speechEnabled 
                    ? 'Tap the mic to start speaking...'
                    : 'Speech recognition not available...' 
                  : _transcribedText,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Wave animation and mic button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isSpeaking)
                    WaveAnimation(
                      isActive: _isSpeaking,
                      soundLevel: _soundLevel,
                      color: Colors.orange.withOpacity(0.5),
                      width: 180,
                      height: 80,
                    ),
                  FloatingActionButton.large(
                    onPressed: _speechEnabled
                      ? (_isSpeaking ? _stopListening : _startListening)
                      : null,
                    backgroundColor: _speechEnabled ? Colors.orange : Colors.grey,
                    child: Icon(
                      _isSpeaking ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _speech.stop();
    super.dispose();
  }
}
