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

    // More realistic skin tones
    final palmPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFDBB5), // Light skin tone center
          const Color(0xFFE8B894), // Darker skin tone edges
        ],
        radius: 0.8,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final fingerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE8B894), // Darker at base
          const Color(0xFFFFDBB5), // Lighter at tips
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 20.0;

    // Shadow paint for depth
    final shadowPaint = Paint()
      ..color = const Color(0x40000000) // Semi-transparent black
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    // Nail paint for fingertips
    final nailPaint = Paint()
      ..color = const Color(0xFFF5F5F5) // Light nail color
      ..style = PaintingStyle.fill;


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
            _drawRealisticHand(canvas, handLandmarkPoints, palmPaint, fingerPaint, shadowPaint, nailPaint, size);
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

  void _drawRealisticHand(Canvas canvas, List<Offset> handLandmarks, Paint palmPaint, Paint fingerPaint, Paint shadowPaint, Paint nailPaint, Size canvasSize) {
    if (handLandmarks.length < 21) return;

    // Calculate dynamic sizing based on hand scale
    final double avgDistance = _calculateAverageDistance(handLandmarks);
    final double baseFingerWidth = avgDistance * 0.4;
    final double tipFingerWidth = avgDistance * 0.25;
    final double nailSize = avgDistance * 0.15;

    // --- 1. Draw Shadows First (for depth) ---
    _drawHandShadows(canvas, handLandmarks, shadowPaint, baseFingerWidth);

    // --- 2. Draw Realistic Palm ---
    _drawRealisticPalm(canvas, handLandmarks, palmPaint);

    // --- 3. Draw Realistic Fingers with Tapering ---
    _drawRealisticFingers(canvas, handLandmarks, fingerPaint, baseFingerWidth, tipFingerWidth);

    // --- 4. Draw Fingernails ---
    _drawFingernails(canvas, handLandmarks, nailPaint, nailSize);

    // --- 5. Add Knuckle Details ---
    _drawKnuckleDetails(canvas, handLandmarks, shadowPaint, avgDistance);
  }

  double _calculateAverageDistance(List<Offset> landmarks) {
    if (landmarks.length < 21) return 20.0;
    
    double totalDistance = 0;
    int count = 0;
    
    // Calculate distances between key landmarks for scaling
    final List<List<int>> keyDistances = [
      [0, 5], [0, 9], [0, 13], [0, 17], // Wrist to finger bases
      [5, 6], [9, 10], [13, 14], [17, 18], // First segments
    ];
    
    for (var pair in keyDistances) {
      if (pair[0] < landmarks.length && pair[1] < landmarks.length) {
        totalDistance += (landmarks[pair[0]] - landmarks[pair[1]]).distance;
        count++;
      }
    }
    
    return count > 0 ? totalDistance / count : 20.0;
  }

  void _drawHandShadows(Canvas canvas, List<Offset> landmarks, Paint shadowPaint, double baseWidth) {
    // Draw subtle shadows offset slightly to give depth
    final shadowOffset = Offset(2, 3);
    
    // Shadow for palm
    _drawPalmShape(canvas, landmarks, shadowPaint, shadowOffset);
    
    // Shadows for fingers
    final fingerGroups = [
      [1, 2, 3, 4], // Thumb
      [5, 6, 7, 8], // Index
      [9, 10, 11, 12], // Middle
      [13, 14, 15, 16], // Ring
      [17, 18, 19, 20], // Pinky
    ];
    
    for (var finger in fingerGroups) {
      for (int i = 0; i < finger.length - 1; i++) {
        if (finger[i] < landmarks.length && finger[i + 1] < landmarks.length) {
          final p1 = landmarks[finger[i]] + shadowOffset;
          final p2 = landmarks[finger[i + 1]] + shadowOffset;
          
          final shadowFingerPaint = Paint()
            ..color = shadowPaint.color
            ..strokeCap = StrokeCap.round
            ..strokeWidth = baseWidth * 0.8;
          
          canvas.drawLine(p1, p2, shadowFingerPaint);
        }
      }
    }
  }

  void _drawRealisticPalm(Canvas canvas, List<Offset> landmarks, Paint palmPaint) {
    _drawPalmShape(canvas, landmarks, palmPaint, Offset.zero);
  }

  void _drawPalmShape(Canvas canvas, List<Offset> landmarks, Paint paint, Offset offset) {
    if (landmarks.length < 18) return;
    
    final palmPath = Path();
    
    // Create a more natural palm shape using curves
    final wrist = landmarks[0] + offset;
    final thumbBase = landmarks[1] + offset;
    final indexBase = landmarks[5] + offset;
    final middleBase = landmarks[9] + offset;
    final ringBase = landmarks[13] + offset;
    final pinkyBase = landmarks[17] + offset;
    
    // Start from wrist
    palmPath.moveTo(wrist.dx, wrist.dy);
    
    // Curve to thumb base
    palmPath.quadraticBezierTo(
      wrist.dx - (wrist.dx - thumbBase.dx) * 0.3,
      wrist.dy - (wrist.dy - thumbBase.dy) * 0.7,
      thumbBase.dx, thumbBase.dy
    );
    
    // Smooth curves between finger bases
    palmPath.quadraticBezierTo(
      (thumbBase.dx + indexBase.dx) * 0.5,
      (thumbBase.dy + indexBase.dy) * 0.4,
      indexBase.dx, indexBase.dy
    );
    
    palmPath.lineTo(middleBase.dx, middleBase.dy);
    palmPath.lineTo(ringBase.dx, ringBase.dy);
    
    // Curve to pinky base
    palmPath.quadraticBezierTo(
      (ringBase.dx + pinkyBase.dx) * 0.5,
      (ringBase.dy + pinkyBase.dy) * 0.9,
      pinkyBase.dx, pinkyBase.dy
    );
    
    // Curve back to wrist
    palmPath.quadraticBezierTo(
      wrist.dx + (pinkyBase.dx - wrist.dx) * 0.7,
      wrist.dy + (pinkyBase.dy - wrist.dy) * 0.3,
      wrist.dx, wrist.dy
    );
    
    canvas.drawPath(palmPath, paint);
  }

  void _drawRealisticFingers(Canvas canvas, List<Offset> landmarks, Paint fingerPaint, double baseWidth, double tipWidth) {
    final fingerGroups = [
      [0, 1, 2, 3, 4], // Thumb (from wrist)
      [0, 5, 6, 7, 8], // Index
      [0, 9, 10, 11, 12], // Middle
      [0, 13, 14, 15, 16], // Ring
      [0, 17, 18, 19, 20], // Pinky
    ];
    
    for (int fingerIndex = 0; fingerIndex < fingerGroups.length; fingerIndex++) {
      final finger = fingerGroups[fingerIndex];
      
      for (int i = 1; i < finger.length - 1; i++) { // Start from 1 to skip wrist connection
        if (finger[i] < landmarks.length && finger[i + 1] < landmarks.length) {
          final p1 = landmarks[finger[i]];
          final p2 = landmarks[finger[i + 1]];
          
          // Calculate tapering width based on segment position
          final progress = i / (finger.length - 2);
          final segmentWidth = baseWidth * (1 - progress * 0.4); // Taper to 60% of base width
          
          final segmentPaint = Paint()
            ..shader = fingerPaint.shader
            ..strokeCap = StrokeCap.round
            ..strokeWidth = segmentWidth;
          
          canvas.drawLine(p1, p2, segmentPaint);
        }
      }
      
      // Draw rounded joints for smoother appearance
      for (int i = 1; i < finger.length; i++) {
        if (finger[i] < landmarks.length) {
          final progress = (i - 1) / (finger.length - 2);
          final jointRadius = baseWidth * (1 - progress * 0.4) * 0.5;
          
          canvas.drawCircle(landmarks[finger[i]], jointRadius, fingerPaint);
        }
      }
    }
  }

  void _drawFingernails(Canvas canvas, List<Offset> landmarks, Paint nailPaint, double nailSize) {
    final fingertips = [4, 8, 12, 16, 20]; // Thumb, Index, Middle, Ring, Pinky tips
    
    for (int tip in fingertips) {
      if (tip < landmarks.length) {
        // Draw small oval nail
        final nailRect = Rect.fromCenter(
          center: landmarks[tip],
          width: nailSize * 1.2,
          height: nailSize * 0.8,
        );
        
        canvas.drawOval(nailRect, nailPaint);
        
        // Add subtle nail highlight
        final highlightPaint = Paint()
          ..color = const Color(0x30FFFFFF)
          ..style = PaintingStyle.fill;
        
        final highlightRect = Rect.fromCenter(
          center: landmarks[tip] + Offset(-nailSize * 0.2, -nailSize * 0.2),
          width: nailSize * 0.6,
          height: nailSize * 0.4,
        );
        
        canvas.drawOval(highlightRect, highlightPaint);
      }
    }
  }

  void _drawKnuckleDetails(Canvas canvas, List<Offset> landmarks, Paint shadowPaint, double avgDistance) {
    final knuckleGroups = [
      [6, 7], [10, 11], [14, 15], [18, 19], // Middle segments of fingers
    ];
    
    final knucklePaint = Paint()
      ..color = shadowPaint.color.withOpacity(0.2)
      ..strokeWidth = 1.0;
    
    for (var knuckle in knuckleGroups) {
      if (knuckle[0] < landmarks.length && knuckle[1] < landmarks.length) {
        final center = Offset(
          (landmarks[knuckle[0]].dx + landmarks[knuckle[1]].dx) / 2,
          (landmarks[knuckle[0]].dy + landmarks[knuckle[1]].dy) / 2,
        );
        
        // Draw subtle knuckle line
        final knuckleRadius = avgDistance * 0.15;
        canvas.drawCircle(center, knuckleRadius, knucklePaint);
      }
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
