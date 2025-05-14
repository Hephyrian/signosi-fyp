import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/translation_response.dart';

class SignAnimationController extends ChangeNotifier {
  List<Sign> _signs = [];
  int _currentSignIndex = 0;
  int _currentFrameIndex = 0;
  bool _isPlaying = false;
  Timer? _animationTimer;
  int _fps = 30;
  bool _useVideoIfAvailable = true;
  
  // Getters
  List<Sign> get signs => _signs;
  Sign? get currentSign => _signs.isNotEmpty ? _signs[_currentSignIndex] : null;
  int get currentSignIndex => _currentSignIndex;
  int get currentFrameIndex => _currentFrameIndex;
  bool get isPlaying => _isPlaying;
  bool get isLastSign => _currentSignIndex >= _signs.length - 1;
  bool get isFirstSign => _currentSignIndex <= 0;
  int get totalSigns => _signs.length;

  // Get flattened landmark data for the current frame
  List<double> get currentFrameLandmarks {
    if (_signs.isEmpty || _currentSignIndex >= _signs.length || _signs[_currentSignIndex].landmarkData == null || _signs[_currentSignIndex].landmarkData!.isEmpty) {
      return [];
    }
    final frameData = _signs[_currentSignIndex].landmarkData![_currentFrameIndex];
    // Flatten the list of lists into a single list of doubles
    return frameData.expand((landmark) => [landmark]).toList();
  }

  // Should we show video for the current sign?
  bool shouldShowVideo(Sign sign) {
    if (!_useVideoIfAvailable) return false;

    // Check if the sign has a valid media path and the file exists
    // This logic might need adjustment if mediaPath is now a URL
    // For now, keeping the original logic but it might be obsolete
    if (sign.mediaPath.isNotEmpty) {
       // Assuming mediaPath is a local file path for video check
       // If we are only using landmark data, this check might be removed
      // final file = File(sign.mediaPath);
      // return file.existsSync();
      return false; // Assuming we are not using local video files anymore
    }
    return false;
  }
  
  // Does the current sign have landmark data?
  bool hasLandmarkData(Sign sign) {
    return sign.landmarkData != null && sign.landmarkData!.isNotEmpty;
  }
  
  // Set the animation data
  void setSignData(List<Sign> signs, {int fps = 30, bool useVideoIfAvailable = true}) {
    _signs = signs;
    _currentSignIndex = 0;
    _currentFrameIndex = 0;
    _fps = fps;
    _useVideoIfAvailable = useVideoIfAvailable;
    notifyListeners();
  }
  
  // Start animation
  void startAnimation() {
    if (_signs.isEmpty || _isPlaying) return;

    final currentSign = _signs[_currentSignIndex];
    // Start animation only if landmark data is available
    if (!hasLandmarkData(currentSign)) return;

    _isPlaying = true;
    _startLandmarkAnimation();
    notifyListeners();
  }
  
  // Stop animation
  void stopAnimation() {
    _animationTimer?.cancel();
    _isPlaying = false;
    notifyListeners();
  }
  
  // Go to next sign
  void nextSign() {
    if (_currentSignIndex < _signs.length - 1) {
      stopAnimation();
      _currentSignIndex++;
      _currentFrameIndex = 0;
      startAnimation(); // Will start if appropriate
      notifyListeners();
    }
  }
  
  // Go to previous sign
  void previousSign() {
    if (_currentSignIndex > 0) {
      stopAnimation();
      _currentSignIndex--;
      _currentFrameIndex = 0;
      startAnimation(); // Will start if appropriate
      notifyListeners();
    }
  }
  
  // Restart current sign
  void restartCurrentSign() {
    stopAnimation();
    _currentFrameIndex = 0;
    startAnimation(); // Will start if appropriate
    notifyListeners();
  }
  
  void _startLandmarkAnimation() {
    if (_signs.isEmpty || !hasLandmarkData(_signs[_currentSignIndex])) return;
    
    final Duration frameDuration = Duration(milliseconds: 1000 ~/ _fps);
    final landmarkFrames = _signs[_currentSignIndex].landmarkData!;

    _animationTimer = Timer.periodic(frameDuration, (timer) {
      if (_currentFrameIndex < landmarkFrames.length - 1) {
        _currentFrameIndex++;
        notifyListeners();
      } else {
        stopAnimation();

        // Auto-advance to next sign if available
        if (_currentSignIndex < _signs.length - 1) {
          _currentSignIndex++;
          _currentFrameIndex = 0;

          // Start the next sign if it has landmark data
          if (hasLandmarkData(_signs[_currentSignIndex])) {
            _startLandmarkAnimation();
          } else {
            _isPlaying = false;
          }
          notifyListeners();
        } else {
           // Animation finished for the last sign
           _isPlaying = false;
           notifyListeners();
        }
      }
    });
  }
  
  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }
}
