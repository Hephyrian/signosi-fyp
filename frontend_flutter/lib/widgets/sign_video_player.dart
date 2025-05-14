import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

class SignVideoPlayer extends StatefulWidget {
  final String videoPath;
  final bool autoPlay;
  final bool looping;
  final Function(bool)? onPlayStatusChanged;
  final Function(String)? onError;

  const SignVideoPlayer({
    Key? key, 
    required this.videoPath,
    this.autoPlay = true,
    this.looping = true,
    this.onPlayStatusChanged,
    this.onError,
  }) : super(key: key);

  @override
  _SignVideoPlayerState createState() => _SignVideoPlayerState();
}

class _SignVideoPlayerState extends State<SignVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    try {
      print('Attempting to load video from path: ${widget.videoPath}');
      final file = File(widget.videoPath);
      if (file.existsSync()) {
        print('Video file exists, initializing player');
        _controller = VideoPlayerController.file(file);
        _controller.initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
              if (widget.autoPlay) {
                _controller.play();
                widget.onPlayStatusChanged?.call(true);
              }
              if (widget.looping) {
                _controller.setLooping(true);
              }
            });
          }
        }).catchError((error) {
          print('Error initializing video: $error');
          if (mounted) {
            setState(() {
              _isError = true;
              _errorMessage = 'Error initializing video: $error';
            });
            widget.onError?.call(_errorMessage);
          }
        });
        
        // Add listener for play status changes
        _controller.addListener(() {
          final isPlaying = _controller.value.isPlaying;
          widget.onPlayStatusChanged?.call(isPlaying);
        });
      } else {
        print('Video file not found: ${widget.videoPath}');
        setState(() {
          _isError = true;
          _errorMessage = 'Video file not found: ${widget.videoPath}';
        });
        widget.onError?.call(_errorMessage);
      }
    } catch (e) {
      print('Error setting up video: $e');
      setState(() {
        _isError = true;
        _errorMessage = 'Error setting up video: $e';
      });
      widget.onError?.call(_errorMessage);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Unable to play video',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _initializeVideoPlayer(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Loading video...'),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller),
          _ControlsOverlay(controller: _controller),
          VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: Theme.of(context).colorScheme.primary,
              bufferedColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;

  const _ControlsOverlay({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child: controller.value.isPlaying
              ? const SizedBox.shrink()
              : Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 80.0,
                      semanticLabel: 'Play',
                    ),
                  ),
                ),
        ),
        GestureDetector(
          onTap: () {
            controller.value.isPlaying ? controller.pause() : controller.play();
          },
        ),
      ],
    );
  }
} 