import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class WhiteboardScreen extends StatefulWidget {
  const WhiteboardScreen({super.key});

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  Color selectedColor = Colors.black;
  double strokeWidth = 3.0;
  bool isErasing = false;
  List<DrawingPoint?> points = [];
  List<List<DrawingPoint?>> allStrokes = [];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Whiteboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear Board',
            onPressed: () {
              setState(() {
                points.clear();
                allStrokes.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Save',
            onPressed: () {
              // TODO: Implement save functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Save feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Canvas area
            Container(
              color: Colors.white,
              width: double.infinity,
              height: double.infinity,
              child: GestureDetector(
                onPanDown: (details) {
                  setState(() {
                    points = [];
                    points.add(
                      DrawingPoint(
                        offset: details.localPosition,
                        paint: Paint()
                          ..color = isErasing ? Colors.white : selectedColor
                          ..strokeWidth = isErasing ? strokeWidth * 2 : strokeWidth
                          ..strokeCap = StrokeCap.round,
                        isEraser: isErasing,
                      ),
                    );
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    points.add(
                      DrawingPoint(
                        offset: details.localPosition,
                        paint: Paint()
                          ..color = isErasing ? Colors.white : selectedColor
                          ..strokeWidth = isErasing ? strokeWidth * 2 : strokeWidth
                          ..strokeCap = StrokeCap.round,
                        isEraser: isErasing,
                      ),
                    );
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    points.add(null);
                    // Save current stroke
                    allStrokes.add(List.from(points));
                  });
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: DrawingPainter(
                      strokes: allStrokes,
                      currentPoints: points,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            // Tool controls
            Positioned(
              bottom: 16,
              right: 16,
              left: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Color selector
                          InkWell(
                            onTap: () {
                              _showColorPicker();
                            },
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: selectedColor,
                            ),
                          ),
                          // Stroke width selector
                          Expanded(
                            child: Row(
                              children: [
                                const SizedBox(width: 8),
                                const Icon(Icons.line_weight, size: 24),
                                Expanded(
                                  child: Slider(
                                    value: strokeWidth,
                                    min: 1.0,
                                    max: 20.0,
                                    onChanged: (value) {
                                      setState(() {
                                        strokeWidth = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Eraser toggle
                          IconButton(
                            icon: Icon(
                              isErasing ? Icons.auto_fix_high : Icons.auto_fix_normal,
                              color: isErasing ? Theme.of(context).colorScheme.primary : Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                isErasing = !isErasing;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: selectedColor,
            onColorChanged: (color) {
              setState(() {
                selectedColor = color;
                isErasing = false;
              });
              Navigator.of(context).pop();
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<List<DrawingPoint?>> strokes;
  final List<DrawingPoint?> currentPoints;

  DrawingPainter({required this.strokes, required this.currentPoints});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all completed strokes
    for (var stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
    
    // Draw current stroke
    _drawStroke(canvas, currentPoints);
  }
  
  void _drawStroke(Canvas canvas, List<DrawingPoint?> points) {
    if (points.isEmpty) return;
    
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        // For erasing, use a white stroke with BlendMode.src
        if (points[i]!.isEraser) {
          final eraserPaint = Paint()
            ..color = Colors.white
            ..strokeWidth = points[i]!.paint.strokeWidth
            ..strokeCap = points[i]!.paint.strokeCap
            ..blendMode = BlendMode.src;
            
          canvas.drawLine(points[i]!.offset, points[i + 1]!.offset, eraserPaint);
        } else {
          // Normal drawing
          canvas.drawLine(points[i]!.offset, points[i + 1]!.offset, points[i]!.paint);
        }
      } else if (points[i] != null && points[i + 1] == null) {
        // Draw a point when there's just a tap
        if (points[i]!.isEraser) {
          final eraserPaint = Paint()
            ..color = Colors.white
            ..strokeWidth = points[i]!.paint.strokeWidth
            ..strokeCap = points[i]!.paint.strokeCap
            ..blendMode = BlendMode.src;
            
          canvas.drawCircle(points[i]!.offset, points[i]!.paint.strokeWidth / 2, eraserPaint);
        } else {
          canvas.drawCircle(points[i]!.offset, points[i]!.paint.strokeWidth / 2, points[i]!.paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class DrawingPoint {
  final Offset offset;
  final Paint paint;
  final bool isEraser;

  DrawingPoint({
    required this.offset,
    required this.paint,
    this.isEraser = false,
  });
} 