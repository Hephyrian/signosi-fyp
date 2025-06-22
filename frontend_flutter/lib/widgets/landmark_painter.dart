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

  // Hand connections (MediaPipe Hand landmarks - 21 landmarks)
  // 0: WRIST
  // 1-4: THUMB (tip is 4)
  // 5-8: INDEX_FINGER (tip is 8)
  // 9-12: MIDDLE_FINGER (tip is 12)
  // 13-16: RING_FINGER (tip is 16)
  // 17-20: PINKY_FINGER (tip is 20)
  static const List<List<int>> handConnections = [
    [0, 1], [1, 2], [2, 3], [3, 4], // Thumb
    [0, 5], [5, 6], [6, 7], [7, 8], // Index finger
    [5, 9], // Index to Middle base (for palm)
    [0, 9], [9, 10], [10, 11], [11, 12], // Middle finger
    [9, 13], // Middle to Ring base (for palm)
    [0, 13], [13, 14], [14, 15], [15, 16], // Ring finger
    [13, 17], // Ring to Pinky base (for palm)
    [0, 17], [17, 18], [18, 19], [19, 20], // Pinky finger
  ];

  // Palm Outline: Connecting the base of the fingers and wrist.
  // Order: Wrist -> Thumb Base -> Index Base -> Middle Base -> Ring Base -> Pinky Base -> Wrist
  static const List<int> palmOutlineIndices = [0, 1, 5, 9, 13, 17];


  // Define connections for each finger
  static const List<List<int>> thumbConnections = [[0,1], [1,2], [2,3], [3,4]];
  static const List<List<int>> indexFingerConnections = [[0,5], [5,6], [6,7], [7,8]]; // Note: 0 is wrist, 5 is base of index
  static const List<List<int>> middleFingerConnections = [[0,9], [9,10], [10,11], [11,12]];
  static const List<List<int>> ringFingerConnections = [[0,13], [13,14], [14,15], [15,16]];
  static const List<List<int>> pinkyFingerConnections = [[0,17], [17,18], [18,19], [19,20]];

  static const List<List<List<int>>> fingerSegmentGroups = [
    thumbConnections,
    indexFingerConnections,
    middleFingerConnections,
    ringFingerConnections,
    pinkyFingerConnections,
  ];


  // Combine pose and hand connections, adjusting indices for combined data
  // Assuming backend sends pose landmarks first, then hand landmarks for each person
  // And assuming 1 person for now
  static List<List<int>> getConnections(int numberOfPoseLandmarks, int numberOfHandLandmarks, bool drawStylizedHands) {
    List<List<int>> connections = [];

    // Add pose connections
    connections.addAll(poseConnections);

    // Add connections between pose and hands (wrist to hand base)
    // Assuming pose landmarks 15 and 16 are wrists (adjust if different)
    // And hand landmark 0 is the base of the hand.
    if (numberOfPoseLandmarks > 15 && numberOfHandLandmarks > 0) {
        // This logic might need to be specific if there are two hands.
        // For now, let's assume pose landmark 15 (e.g., right wrist) connects to the start of the first hand's landmarks.
        connections.add([15, numberOfPoseLandmarks]); 
    }
    // If you have a left wrist (e.g., pose landmark 16) and a second hand:
    // connections.add([16, numberOfPoseLandmarks + numberOfHandLandmarks]); // Left wrist to left hand base

    if (!drawStylizedHands && numberOfHandLandmarks > 0) {
      // Add traditional hand connections only if not drawing stylized hands
      int handStartIndex = numberOfPoseLandmarks;
      for (var connection in LandmarkConnections.handConnections) { // Use the class member
        connections.add([connection[0] + handStartIndex, connection[1] + handStartIndex]);
      }
    }
    return connections;
  }
}


class LandmarkPainter extends CustomPainter {
  final List<double> landmarkData; // Flattened list of landmark coordinates for a single frame
  final int numberOfPoseLandmarks;
  final int numberOfHandLandmarks; // Landmarks per hand (e.g., 21)
  final int numberOfHands; // Number of hands to draw (e.g., 1 or 2)
  final bool isWorldLandmarks; // True if using world landmarks (3D), false for image landmarks (2D)
  final bool drawStylizedHands; // New flag to control hand drawing style

  LandmarkPainter({
    required this.landmarkData,
    required this.numberOfPoseLandmarks,
    required this.numberOfHandLandmarks,
    this.numberOfHands = 1, // Default to one hand
    required this.isWorldLandmarks,
    this.drawStylizedHands = true, // Default to new style
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarkData.isEmpty) {
      return;
    }

    final landmarkPaint = Paint()
      ..color = Colors.blueAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    final handPaint = Paint()
      ..color = const Color(0xFFFFD54F) // Yellowish-Orange, similar to image
      ..style = PaintingStyle.fill;

    final fingerPaint = Paint()
      ..color = const Color(0xFFFFB74D) // Slightly darker/more orange for fingers
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 20.0; // Will be adjusted dynamically or be fixed


    const int featuresPerLandmark = 5; // x, y, z, visibility, presence

    // --- 1. Extract and Transform Landmarks ---
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    List<Offset> allRawPoints = [];

    for (int i = 0; i < landmarkData.length; i += featuresPerLandmark) {
      double x = landmarkData[i];
      double y = landmarkData[i + 1];
      // double z = landmarkData[i + 2]; // Available if needed
      // double visibility = landmarkData[i + 3];
      // double presence = landmarkData[i + 4];

      // For now, only consider landmarks if visibility and presence are high (optional)
      // if (visibility < 0.5 || presence < 0.5) {
      //   // Add a placeholder or skip, affects indexing if skipped
      //   allRawPoints.add(Offset.zero); // Or handle missing points
      //   continue;
      // }
      allRawPoints.add(Offset(x, y));
      minX = min(minX, x);
      minY = min(minY, y);
      maxX = max(maxX, x);
      maxY = max(maxY, y);
    }

    if (allRawPoints.isEmpty || (maxX - minX == 0) || (maxY - minY == 0)) {
        // Avoid division by zero or if no valid points
        return;
    }
    
    double boundingBoxWidth = maxX - minX;
    double boundingBoxHeight = maxY - minY;

    // Add some padding to the bounding box to prevent clipping at edges
    double padding = boundingBoxWidth * 0.1; 
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;
    boundingBoxWidth = maxX - minX;
    boundingBoxHeight = maxY - minY;


    double scaleX = size.width / boundingBoxWidth;
    double scaleY = size.height / boundingBoxHeight;
    double scale = min(scaleX, scaleY) * 0.8; // Use 80% of available space

    double offsetX = (size.width - boundingBoxWidth * scale) / 2 - minX * scale;
    double offsetY = (size.height - boundingBoxHeight * scale) / 2 - minY * scale;

    final List<Offset> transformedPoints = allRawPoints.map((point) {
      return Offset(point.dx * scale + offsetX, point.dy * scale + offsetY);
    }).toList();

    // --- 2. Draw Pose Landmarks and Connections (if any) ---
    if (numberOfPoseLandmarks > 0) {
      final poseLandmarks = transformedPoints.sublist(0, numberOfPoseLandmarks);
      final connections = LandmarkConnections.getConnections(numberOfPoseLandmarks, numberOfHandLandmarks, drawStylizedHands);
      
      // Draw pose connections
      for (var connection in connections) {
          // Only draw connections that are within the pose landmark range or connect to hands if not stylized
          bool isPoseConnection = connection[0] < numberOfPoseLandmarks && connection[1] < numberOfPoseLandmarks;
          bool isPoseToHandConnection = (connection[0] < numberOfPoseLandmarks && connection[1] >= numberOfPoseLandmarks) ||
                                        (connection[1] < numberOfPoseLandmarks && connection[0] >= numberOfPoseLandmarks);

          if (isPoseConnection || (isPoseToHandConnection && !drawStylizedHands)) {
            if (connection[0] < transformedPoints.length && connection[1] < transformedPoints.length) {
                 canvas.drawLine(transformedPoints[connection[0]], transformedPoints[connection[1]], landmarkPaint);
            }
          }
      }
      // Draw pose landmark points
      for (int i = 0; i < poseLandmarks.length; i++) {
        canvas.drawCircle(poseLandmarks[i], landmarkPaint.strokeWidth / 2, landmarkPaint);
      }
    }

    // --- 3. Draw Hand Landmarks ---
    if (numberOfHandLandmarks > 0 && numberOfHands > 0) {
      for (int handIndex = 0; handIndex < numberOfHands; handIndex++) {
        int handDataStartIndex = numberOfPoseLandmarks + (handIndex * numberOfHandLandmarks * featuresPerLandmark);
        // The actual points in transformedPoints list
        int handPointsStartIndex = numberOfPoseLandmarks + (handIndex * numberOfHandLandmarks);
        
        if (handPointsStartIndex + numberOfHandLandmarks <= transformedPoints.length) {
          final handLandmarkPoints = transformedPoints.sublist(
            handPointsStartIndex,
            handPointsStartIndex + numberOfHandLandmarks,
          );

          if (drawStylizedHands) {
            _drawStylizedHand(canvas, handLandmarkPoints, handPaint, fingerPaint, size);
          } else {
            // Draw traditional hand landmarks and connections if not stylized
            final traditionalHandConnections = LandmarkConnections.handConnections;
            for (var connection in traditionalHandConnections) {
              if (connection[0] < handLandmarkPoints.length && connection[1] < handLandmarkPoints.length) {
                canvas.drawLine(handLandmarkPoints[connection[0]], handLandmarkPoints[connection[1]], landmarkPaint);
              }
            }
            for (var point in handLandmarkPoints) {
              canvas.drawCircle(point, landmarkPaint.strokeWidth / 2, landmarkPaint);
            }
          }
        }
      }
    }
  }

  void _drawStylizedHand(Canvas canvas, List<Offset> handLandmarks, Paint palmPaint, Paint fingerPaint, Size canvasSize) {
    if (handLandmarks.length < 21) return; // Expect 21 landmarks

   
    final double fingerBaseWidth = canvasSize.width * 0.04; 
    final double fingertipWidth = canvasSize.width * 0.03;
    final double palmOutlineStrokeWidth = canvasSize.width * 0.01;


    
    final palmPath = Path();
    final List<int> palmIndices = LandmarkConnections.palmOutlineIndices; // [0, 1, 5, 9, 13, 17];

    if (palmIndices.every((index) => index < handLandmarks.length)) {
        palmPath.moveTo(handLandmarks[palmIndices[0]].dx, handLandmarks[palmIndices[0]].dy);
        for (int i = 1; i < palmIndices.length; i++) {
            palmPath.lineTo(handLandmarks[palmIndices[i]].dx, handLandmarks[palmIndices[i]].dy);
        }
        
        palmPath.lineTo(handLandmarks[5].dx, handLandmarks[5].dy); // Connect pinky base to index base for a fuller palm top
        palmPath.close(); // Close the path (connects last point to first)
        
        // Create a slightly inset path for the "palm" color to avoid overlap with fingers
        // Or, draw fingers first and then palm, or use different layering.
        // For now, simple fill.
        canvas.drawPath(palmPath, palmPaint);

        // Draw circles at palm joints for a softer look (optional)
        // for (int index in palmIndices) {
        //     canvas.drawCircle(handLandmarks[index], fingerBaseWidth * 0.5, palmPaint);
        // }
    }


    // --- 2. Draw Fingers ---
    // Each finger is a series of connected segments.
    // We'll draw each segment as a thick line with rounded caps.
    // Connections:
    // Thumb: 0-1, 1-2, 2-3, 3-4
    // Index: 0-5, 5-6, 6-7, 7-8
    // Middle:0-9, 9-10, 10-11, 11-12
    // Ring:  0-13, 13-14, 14-15, 15-16
    // Pinky: 0-17, 17-18, 18-19, 19-20

    // Use the defined finger segment groups
    final List<List<List<int>>> fingerSegments = LandmarkConnections.fingerSegmentGroups;

    // Adjust finger paint stroke width based on segment (e.g., thicker at base)
    // For simplicity, start with a fixed width. Can use distance between points too.
    // Let's calculate a base stroke width dynamically
    double avgProximalSegmentLength = 0;
    int count = 0;
    if (handLandmarks[0] != null && handLandmarks[5] != null && handLandmarks[9] != null && handLandmarks[13] != null && handLandmarks[17] != null &&
        handLandmarks[1] != null) {
        avgProximalSegmentLength += (handLandmarks[0] - handLandmarks[1]).distance; // Wrist to Thumb base
        avgProximalSegmentLength += (handLandmarks[0] - handLandmarks[5]).distance;
        avgProximalSegmentLength += (handLandmarks[0] - handLandmarks[9]).distance;
        avgProximalSegmentLength += (handLandmarks[0] - handLandmarks[13]).distance;
        avgProximalSegmentLength += (handLandmarks[0] - handLandmarks[17]).distance;
        count = 5;
    }
    if (count > 0) {
       fingerPaint.strokeWidth = (avgProximalSegmentLength / count) * 0.5; // e.g. 50% of avg proximal segment length
       fingerPaint.strokeWidth = fingerPaint.strokeWidth.clamp(canvasSize.width * 0.02, canvasSize.width * 0.08); // Clamp to reasonable min/max
    } else {
       fingerPaint.strokeWidth = canvasSize.width * 0.04; // Fallback
    }


    for (List<List<int>> finger in fingerSegments) {
      for (List<int> segment in finger) {
        if (segment[0] < handLandmarks.length && segment[1] < handLandmarks.length) {
          Offset p1 = handLandmarks[segment[0]];
          Offset p2 = handLandmarks[segment[1]];
          
          // Make fingers slightly thicker towards the base?
          // For now, uniform thickness.
          canvas.drawLine(p1, p2, fingerPaint);
        }
      }
    }
    
    // Draw circles at each landmark point for the fingers to make joints look smoother and rounder
    // This should be done AFTER lines so circles are on top and create the rounded joint effect
    for (List<List<int>> finger in fingerSegments) {
        for(List<int> segment in finger) {
            // Draw circle at the start of the segment (p1)
            if (segment[0] < handLandmarks.length) {
                 canvas.drawCircle(handLandmarks[segment[0]], fingerPaint.strokeWidth / 2, fingerPaint);
            }
            // Draw circle at the end of the segment (p2), ensures fingertips are round
            if (segment[1] < handLandmarks.length) {
                 canvas.drawCircle(handLandmarks[segment[1]], fingerPaint.strokeWidth / 2, fingerPaint);
            }
        }
    }
    // Ensure wrist is also drawn with a circle if it's part of the "finger" segments (like for thumb base)
    if (0 < handLandmarks.length) {
        canvas.drawCircle(handLandmarks[0], fingerPaint.strokeWidth / 2, fingerPaint);
    }

  }

  @override
  bool shouldRepaint(covariant LandmarkPainter oldDelegate) {
    // Repaint if the landmark data, or any display parameter, changes
    return oldDelegate.landmarkData != landmarkData ||
           oldDelegate.numberOfPoseLandmarks != numberOfPoseLandmarks ||
           oldDelegate.numberOfHandLandmarks != numberOfHandLandmarks ||
           oldDelegate.numberOfHands != numberOfHands ||
           oldDelegate.isWorldLandmarks != isWorldLandmarks ||
           oldDelegate.drawStylizedHands != drawStylizedHands;
  }
}
