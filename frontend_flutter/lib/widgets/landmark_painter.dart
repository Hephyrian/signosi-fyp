import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math';

// Define connections for drawing the skeletal structure
// These connections are based on MediaPipe landmarks (Pose and Hands)
// You might need to adjust these based on the exact landmark structure provided by the backend
class LandmarkConnections {
  // Pose connections (simplified example)
  static const List<List<int>> poseConnections = [
    [0, 1], [1, 2], [2, 3], [3, 7], [0, 4], [4, 5], [5, 6], [6, 8], // Arms
    [9, 10], // Shoulders
    [11, 12], [12, 14], [14, 16], [11, 13], [13, 15], // Legs (simplified)
    // Add more pose connections as needed
  ];

  // Hand connections (MediaPipe Hand landmarks)
  static const List<List<int>> handConnections = [
    [0, 1], [1, 2], [2, 3], [3, 4], // Thumb
    [0, 5], [5, 6], [6, 7], [7, 8], // Index finger
    [0, 9], [9, 10], [10, 11], [11, 12], // Middle finger
    [0, 13], [13, 14], [14, 15], [15, 16], // Ring finger
    [0, 17], [17, 18], [18, 19], [19, 20], // Pinky finger
    [0, 5], [9, 13], [17, 0], // Palm base connections
  ];

  // Combine pose and hand connections, adjusting indices for combined data
  // Assuming backend sends pose landmarks first, then hand landmarks for each person
  // And assuming 1 person for now
  static List<List<int>> getConnections(int numberOfPoseLandmarks, int numberOfHandLandmarks) {
    List<List<int>> connections = [];

    // Add pose connections
    connections.addAll(poseConnections);

    // Add hand connections (adjusting indices)
    int handStartIndex = numberOfPoseLandmarks;
    for (var connection in handConnections) {
      connections.add([connection[0] + handStartIndex, connection[1] + handStartIndex]);
    }

    // Add connections between pose and hands (wrist to hand base)
    // Assuming pose landmarks 15 and 16 are wrists
    // Assuming hand landmark 0 is the base of the hand
    connections.add([15, numberOfPoseLandmarks]); // Right wrist to right hand base
    connections.add([16, numberOfPoseLandmarks + numberOfHandLandmarks]); // Left wrist to left hand base


    return connections;
  }
}


class LandmarkPainter extends CustomPainter {
  final List<double> landmarkData; // Flattened list of landmark coordinates for a single frame
  final int numberOfPoseLandmarks;
  final int numberOfHandLandmarks;
  final bool isWorldLandmarks; // True if using world landmarks (3D), false for image landmarks (2D)

  LandmarkPainter({
    required this.landmarkData,
    required this.numberOfPoseLandmarks,
    required this.numberOfHandLandmarks,
    required this.isWorldLandmarks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarkData.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = Colors.blueAccent // Color of the landmarks and connections
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    final points = <Offset>[];
    // Assuming each landmark has 5 features: x, y, z, visibility, presence
    const int featuresPerLandmark = 5;

    // Extract points and calculate bounding box
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (int i = 0; i < landmarkData.length; i += featuresPerLandmark) {
      double x = landmarkData[i];
      double y = landmarkData[i + 1];

      points.add(Offset(x, y));

      // Update bounding box
      minX = min(minX, x);
      minY = min(minY, y);
      maxX = max(maxX, x);
      maxY = max(maxY, y);
    }

    // Calculate scaling factor and offset
    double boundingBoxWidth = maxX - minX;
    double boundingBoxHeight = maxY - minY;

    double scaleX = size.width / boundingBoxWidth;
    double scaleY = size.height / boundingBoxHeight;
    double scale = min(scaleX, scaleY); // Maintain aspect ratio

    // Calculate offset to center the scaled animation
    double offsetX = (size.width - boundingBoxWidth * scale) / 2 - minX * scale;
    double offsetY = (size.height - boundingBoxHeight * scale) / 2 - minY * scale;

    // Apply scaling and offset to points
    final transformedPoints = points.map((point) {
      return Offset(point.dx * scale + offsetX, point.dy * scale + offsetY);
    }).toList();


    // Draw connections
    final connections = LandmarkConnections.getConnections(numberOfPoseLandmarks, numberOfHandLandmarks);
    for (var connection in connections) {
      if (connection[0] < transformedPoints.length && connection[1] < transformedPoints.length) {
        canvas.drawLine(transformedPoints[connection[0]], transformedPoints[connection[1]], paint);
      }
    }

    // Draw landmarks (points)
    for (var point in transformedPoints) {
      canvas.drawCircle(point, paint.strokeWidth / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LandmarkPainter oldDelegate) {
    // Repaint if the landmark data changes
    return oldDelegate.landmarkData != landmarkData;
  }
}
