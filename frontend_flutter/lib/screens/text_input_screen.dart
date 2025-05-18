import 'package:flutter/material.dart';
import 'sign_display_screen.dart';

class TextInputScreen extends StatefulWidget {
  const TextInputScreen({Key? key}) : super(key: key);

  @override
  _TextInputScreenState createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<TextInputScreen> {
  final TextEditingController _textController = TextEditingController();
  String _selectedLanguage = 'si'; // Default to Sinhala
  bool _isSubmitting = false;

  final Map<String, String> _languages = {
    'si': 'Sinhala',
    'en': 'English',
    'ta': 'Tamil',
  };

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitText() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _isSubmitting = true;
      });
      
      // Briefly show loading state
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SignDisplayScreen(
                textToTranslate: text,
                sourceLanguage: _selectedLanguage,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Input'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter text to translate:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Type text here...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitText(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Language:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: _languages.entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: _selectedLanguage == entry.key,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedLanguage = entry.key;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitText,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Translate',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
} 