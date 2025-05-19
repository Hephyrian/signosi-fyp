import 'package:flutter/material.dart';
import 'package:google_speech/google_speech.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../widgets/wave_animation.dart';
import '../widgets/app_navigation_bar.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'sign_display_screen.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

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
  String _selectedLanguage = 'si_LK'; // Default to Sinhala
  bool _isNavigating = false; // Flag to prevent duplicate navigation

  // Map for displaying language names in UI
  final Map<String, String> _availableLanguages = {
    'si_LK': 'Sinhala',
    'en_US': 'English (US)',
    'ta_LK': 'Tamil',
  };

  // Map speech recognition locale to API source_language code
  final Map<String, String> _localeToApiCode = {
    'si_LK': 'si',
    'en_US': 'en',
    'ta_LK': 'ta',
  };

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadDefaultLanguage();
  }

  void _loadDefaultLanguage() {
    final defaultLang = dotenv.env['DEFAULT_LANGUAGE'] ?? 'si';
    // Map the default language code to the speech recognition locale
    if (defaultLang == 'si') {
      _selectedLanguage = 'si_LK';
    } else if (defaultLang == 'en') {
      _selectedLanguage = 'en_US';
    } else if (defaultLang == 'ta') {
      _selectedLanguage = 'ta_LK';
    }
  }

  Future<void> _initSpeech() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      print('Microphone permission granted');
      try {
        // Initialize speech_to_text package
        _speech = stt.SpeechToText();
        bool available = await _speech.initialize(
          onStatus: (status) {
            print('Speech status: $status');
          },
          onError: (error) => print('Speech error: $error'),
        );
        
        if (available) {
          print('Speech to Text initialized successfully');
          setState(() {
            _speechEnabled = true;
          });
        } else {
          print('Speech to Text initialization failed');
          setState(() {
            _speechEnabled = false;
            _transcribedText = 'Failed to initialize speech recognition.';
          });
        }
      } catch (e) {
        print('Error initializing speech recognition: $e');
        setState(() {
          _speechEnabled = false;
          _transcribedText = 'Failed to initialize speech recognition.';
        });
      }
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

    setState(() {
      _isSpeaking = true;
      _transcribedText = '';
      _soundLevel = 0.0;
      _isNavigating = false;
    });

    try {
      // Using speech_to_text package for audio streaming
      await _speech.listen(
        onResult: (result) {
          print('onResult triggered: $result');
          setState(() {
            _transcribedText = result.recognizedWords;
            print('Recognized text: $_transcribedText');
            if (result.hasConfidenceRating && result.confidence > 0) {
              _soundLevel = result.confidence * 100;
            }
          });
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
        localeId: _selectedLanguage,
        onSoundLevelChange: (level) {
          print('onSoundLevelChange triggered: $level');
          setState(() {
            _soundLevel = level;
          });
        },
      );
    } catch (e) {
      print('Error with speech recognition: $e');
      setState(() {
        _isSpeaking = false;
        _transcribedText = e.toString().contains('error_speech_timeout')
            ? 'Speech recognition timed out. No speech detected. Please try again.'
            : 'Speech recognition error. Please try again.';
      });
    }
  }
  
  // Handle manual stop (user presses stop button)
  Future<void> _manualStopListening() async {
    if (!mounted) return;
    
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
      });
    }
    
    _navigateToSignScreen();
  }
  
  void _navigateToSignScreen() {
    if (_isNavigating || !mounted || _transcribedText.isEmpty) return;
    
    setState(() {
      _isNavigating = true;
    });
    
    print('Navigating to sign screen with text: $_transcribedText');
    print('Selected language: $_selectedLanguage, Mapped source language: ${_localeToApiCode[_selectedLanguage] ?? 'si'}');
    
    // Get the source_language code for the API
    final sourceLanguage = _localeToApiCode[_selectedLanguage] ?? 'si';
    
    // Wait a bit to ensure the UI shows the stop state before navigating
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SignDisplayScreen(
              textToTranslate: _transcribedText,
              sourceLanguage: sourceLanguage,
            ),
          ),
        ).then((_) {
          // Reset navigation flag after returning
          if (mounted) {
            setState(() {
              _isNavigating = false;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppNavigationBar(
        activeScreen: 'speech',
        isDarkMode: themeProvider.isDarkMode,
        onToggleTheme: () => themeProvider.toggleTheme(),
      ),
      body: Stack(
        children: [
          // Language selector
          Positioned(
            top: 8,
            right: 8,
            child: PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.language,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _availableLanguages[_selectedLanguage] ?? 'Language',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              tooltip: 'Select Language',
              onSelected: (String langCode) {
                setState(() {
                  _selectedLanguage = langCode;
                });
              },
              itemBuilder: (BuildContext context) {
                return _availableLanguages.entries.map((entry) {
                  return PopupMenuItem<String>(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(
                          _selectedLanguage == entry.key ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: _selectedLanguage == entry.key ? Theme.of(context).colorScheme.primary : null,
                        ),
                        const SizedBox(width: 8),
                        Text(entry.value),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          ),

          // Transcribed text area
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _transcribedText.isEmpty 
                      ? _speechEnabled 
                        ? 'Tap the mic to start speaking...'
                        : 'Speech recognition not available...' 
                      : _transcribedText,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
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
                    onPressed: _speechEnabled && !_isNavigating
                      ? (_isSpeaking ? _manualStopListening : _startListening)
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
