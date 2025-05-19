import 'package:flutter/material.dart';
import 'sign_display_screen.dart';
import 'speech_screen.dart';
import '../services/translation_service.dart';
import '../widgets/app_navigation_bar.dart';
import 'dart:convert';

class DebugScreen extends StatefulWidget {
  const DebugScreen({Key? key}) : super(key: key);

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final TextEditingController _textController = TextEditingController();
  String _selectedLanguage = 'si';
  String _debugOutput = '';
  bool _isLoading = false;
  
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
  
  void _navigateToSignScreen() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text')),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignDisplayScreen(
          textToTranslate: _textController.text.trim(),
          sourceLanguage: _selectedLanguage,
        ),
      ),
    );
  }
  
  void _navigateToSpeechScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SpeechScreen(),
      ),
    );
  }
  
  Future<void> _testAPIDirectly() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _debugOutput = 'Sending request to API...';
    });
    
    try {
      final text = _textController.text.trim();
      final response = await TranslationService.translateTextToSign(
        text, 
        _selectedLanguage
      );
      
      setState(() {
        _debugOutput = 'API Response:\n'
            'Number of signs: ${response.signs.length}\n'
            'Sign paths: ${response.signs.map((s) => s.mediaPath).join('\n')}\n';
      });
    } catch (e) {
      setState(() {
        _debugOutput = 'API Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppNavigationBar(activeScreen: 'debug'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter text to translate:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Enter text here...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text(
                'Select language:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Radio<String>(
                    value: 'si',
                    groupValue: _selectedLanguage,
                    onChanged: (value) {
                      setState(() {
                        _selectedLanguage = value!;
                      });
                    },
                  ),
                  const Text('Sinhala'),
                  Radio<String>(
                    value: 'en',
                    groupValue: _selectedLanguage,
                    onChanged: (value) {
                      setState(() {
                        _selectedLanguage = value!;
                      });
                    },
                  ),
                  const Text('English'),
                  Radio<String>(
                    value: 'ta',
                    groupValue: _selectedLanguage,
                    onChanged: (value) {
                      setState(() {
                        _selectedLanguage = value!;
                      });
                    },
                  ),
                  const Text('Tamil'),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Testing Options:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _navigateToSignScreen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Test Sign Screen Navigation'),
                  ),
                  ElevatedButton(
                    onPressed: _navigateToSpeechScreen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Test Speech Screen'),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _testAPIDirectly,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Test API Directly'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Debug Output:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Text(_debugOutput.isEmpty ? 'No debug info yet...' : _debugOutput),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 