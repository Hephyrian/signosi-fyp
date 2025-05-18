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
  
  List<double> _currentFrameLandmarks = [];

  // Callback for when the animation of the CURRENTLY LOADED sign completes
  VoidCallback? onAnimationComplete;
  
  // Getters
  List<Sign> get signs => _signs;
  Sign? get currentSign => _signs.isNotEmpty && _currentSignIndex < _signs.length ? _signs[_currentSignIndex] : null;
  int get currentSignIndex => _currentSignIndex;
  int get currentFrameIndex => _currentFrameIndex;
  bool get isPlaying => _isPlaying;
  bool get isLastSign => _signs.isEmpty || _currentSignIndex >= _signs.length - 1;
  bool get isFirstSign => _currentSignIndex == 0;
  int get totalSigns => _signs.length;

  // Get flattened landmark data for the current frame
  List<double> get currentFrameLandmarks => _currentFrameLandmarks;

  // Getter to check if animation is currently running
  bool get isAnimating => _animationTimer?.isActive ?? false;

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
  void setSignData(List<Sign> newSigns, {int fps = 30}) {
    // This controller now only expects to handle one sign with landmark data at a time.
    // Filter for signs that have landmark data, and take the first one if multiple are passed.
    _signs = newSigns.where((s) => s.landmarkData != null && s.landmarkData!.isNotEmpty).toList();
    
    _fps = fps;
    _currentSignIndex = 0; // Always operates on the first (or only) sign in its internal list
    _currentFrameIndex = 0;
    _currentFrameLandmarks = [];
    if (_signs.isNotEmpty && _signs[0].landmarkData!.isNotEmpty) {
      _currentFrameLandmarks = _signs[0].landmarkData![0];
    }
    notifyListeners();
  }
  
  // Start animation
  void startAnimation() {
    stopAnimation(); // Ensure any previous timer is cancelled

    if (_signs.isEmpty) {
      print("SignAnimationController: No signs with landmark data to animate.");
      _currentFrameLandmarks = [];
      onAnimationComplete?.call(); 
      notifyListeners();
      return;
    }
    
    // Operates on the first sign in its internal _signs list
    final Sign signToAnimate = _signs[0]; 
    final currentSignFrames = signToAnimate.landmarkData;

    if (currentSignFrames == null || currentSignFrames.isEmpty) {
       print("SignAnimationController: Landmark data is null or empty for the sign.");
       _currentFrameLandmarks = [];
       onAnimationComplete?.call(); 
       notifyListeners();
       return;
    }
    
    _currentFrameIndex = 0;
    _updateLandmarksForCurrentFrame();

    _animationTimer = Timer.periodic(Duration(milliseconds: 1000 ~/ _fps), (timer) {
      if (_currentFrameIndex < currentSignFrames.length - 1) {
        _currentFrameIndex++;
        _updateLandmarksForCurrentFrame();
      } else {
        stopAnimation(); // Stop timer as current sign animation is complete
        onAnimationComplete?.call(); // Inform that the current sign's animation is done
      }
      notifyListeners();
    });
  }
  
  void _updateLandmarksForCurrentFrame() {
    if (_signs.isNotEmpty) {
        final Sign signToAnimate = _signs[0];
        final currentSignData = signToAnimate.landmarkData;
        if (currentSignData != null && _currentFrameIndex < currentSignData.length) {
            _currentFrameLandmarks = currentSignData[_currentFrameIndex];
        } else {
            _currentFrameLandmarks = []; // Reset if data is missing or frame index is out of bounds
        }
    } else {
        _currentFrameLandmarks = [];
    }
  }
  
  // Stop animation
  void stopAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
    // notifyListeners(); // Notifying here can cause rapid rebuilds if called frequently
  }
  
  // Method to clear all data and stop animation
  void clearData() {
    print("SignAnimationController: Clearing data.");
    stopAnimation();
    _signs = [];
    _currentSignIndex = 0; // This index is less relevant as we animate one sign at a time now
    _currentFrameIndex = 0;
    _currentFrameLandmarks = [];
    onAnimationComplete = null; // Reset callback
    notifyListeners();
  }
  
  // These navigation methods are less relevant if SignDisplayScreen manages the overall sign sequence
  // and re-calls setSignData for each new landmark sign.
  // Keeping them might be useful if the controller needs to manage a sub-sequence internally in the future.

  void previousSign() { 
    // This would require SignDisplayScreen to call setSignData with the new sign.
    // The controller itself doesn't know about the larger sequence.
    print("SignAnimationController: previousSign called - display screen should manage sequence.");
  }

  void nextSign() {
    // Similarly, display screen should manage this.
    print("SignAnimationController: nextSign called - display screen should manage sequence.");
  }

  void restartCurrentSign() {
    if (_signs.isNotEmpty) {
        _currentFrameIndex = 0;
        print("SignAnimationController: Restarting current sign animation.");
        startAnimation();
    } else {
        print("SignAnimationController: No sign data to restart.");
    }
  }
  
  @override
  void dispose() {
    stopAnimation();
    super.dispose();
  }
}
