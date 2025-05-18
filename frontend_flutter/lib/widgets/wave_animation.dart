import 'dart:math';
import 'package:flutter/material.dart';

class WaveAnimation extends StatefulWidget {
  final bool isActive;
  final double soundLevel;
  final Color color;
  final double width;
  final double height;

  const WaveAnimation({
    Key? key,
    required this.isActive,
    this.soundLevel = 0.0,
    this.color = Colors.orange,
    this.width = 300,
    this.height = 100,
  }) : super(key: key);

  @override
  State<WaveAnimation> createState() => _WaveAnimationState();
}

class _WaveAnimationState extends State<WaveAnimation> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  final int _numBars = 30; // Number of vertical bars
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _controllers = List.generate(
      _numBars,
      (index) => AnimationController(
        duration: Duration(milliseconds: 500 + _random.nextInt(1000)),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.1, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    // Start animations with random delays
    for (var i = 0; i < _controllers.length; i++) {
      if (widget.isActive) {
        _controllers[i].repeat(reverse: true);
      }
    }
  }

  @override
  void didUpdateWidget(WaveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        for (var controller in _controllers) {
          controller.repeat(reverse: true);
        }
      } else {
        for (var controller in _controllers) {
          controller.stop();
        }
      }
    }
    // Sound level changes are handled in the painter
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: widget.isActive
          ? AnimatedBuilder(
              animation: Listenable.merge(_controllers),
              builder: (context, child) {
                return CustomPaint(
                  painter: WaveformPainter(
                    animations: _animations.map((a) => a.value).toList(),
                    color: widget.color,
                    soundLevel: widget.soundLevel,
                  ),
                  size: Size(widget.width, widget.height),
                );
              },
            )
          : const SizedBox(),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> animations;
  final Color color;
  final double soundLevel;

  WaveformPainter({
    required this.animations,
    required this.color,
    this.soundLevel = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final barWidth = size.width / (animations.length * 2 - 1);
    final amplitudeFactor = soundLevel > 0 ? (soundLevel / 15).clamp(0.2, 1.0) : 0.5;

    for (var i = 0; i < animations.length; i++) {
      final baseHeight = size.height * animations[i] * 0.8;
      final barHeight = baseHeight * amplitudeFactor;
      final left = i * barWidth * 2;
      
      // Draw bar from center
      final rect = Rect.fromLTWH(
        left,
        (size.height - barHeight) / 2,
        barWidth,
        barHeight,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return animations != oldDelegate.animations || color != oldDelegate.color || soundLevel != oldDelegate.soundLevel;
  }
}
