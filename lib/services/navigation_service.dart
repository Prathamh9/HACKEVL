// import 'dart:typed_data';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter/services.dart' show rootBundle;

// enum NavigationDecision { left, right, forward, stop, unknown }

// class Detection {
//   final String label;
//   final double x; // normalized center x
//   final double y; // normalized center y
//   final double w;
//   final double h;
//   final double confidence;

//   Detection(this.label, this.x, this.y, this.w, this.h, this.confidence);
// }

// class NavigationService {
//   Interpreter? _interpreter;
//   final bool useAiModel;
//   late List<String> labels;

//   NavigationService({this.useAiModel = true});

//   /// Load TFLite model and labels
//   Future<void> loadModel() async {
//     try {
//       // Load interpreter from assets (assumes asset path declared in pubspec)
//       _interpreter = await Interpreter.fromAsset('assets/ssd_mobilenet.tflite');

//       // Load labels using rootBundle (no BuildContext needed)
//       final labelData =
//           await rootBundle.loadString('assets/ssd_mobilenet_labels.txt');
//       labels = labelData
//           .split('\n')
//           .map((e) => e.trim())
//           .where((e) => e.isNotEmpty)
//           .toList();
//     } catch (e) {
//       // You might want to rethrow or log in production
//       rethrow;
//     }
//   }

//   /// Convert YUV420 to RGB (basic direct conversion)
//   /// NOTE: This implementation assumes packed U/V planes with chroma subsampling 4:2:0.
//   /// For robust use on real devices you should honor plane.pixelStride and plane.bytesPerRow.
//   Uint8List _convertYUV420toRGB(CameraImage image) {
//     final width = image.width;
//     final height = image.height;
//     final yPlane = image.planes[0].bytes;
//     final uPlane = image.planes[1].bytes;
//     final vPlane = image.planes[2].bytes;

//     final rgb = Uint8List(width * height * 3);
//     int index = 0;

//     for (int row = 0; row < height; row++) {
//       for (int col = 0; col < width; col++) {
//         final yp = row * width + col;
//         final uvIndex = (row ~/ 2) * (width ~/ 2) + (col ~/ 2);

//         final Y = yPlane[yp].toInt();
//         final U = uPlane[uvIndex].toInt() - 128;
//         final V = vPlane[uvIndex].toInt() - 128;

//         int r = (Y + 1.402 * V).clamp(0, 255).toInt();
//         int g = (Y - 0.344136 * U - 0.714136 * V).clamp(0, 255).toInt();
//         int b = (Y + 1.772 * U).clamp(0, 255).toInt();

//         rgb[index++] = r;
//         rgb[index++] = g;
//         rgb[index++] = b;
//       }
//     }
//     return rgb;
//   }

//   /// Run detection on a CameraImage
//   Future<List<Detection>> detectObjectsFromFrame(CameraImage image) async {
//     if (_interpreter == null) return [];
//     if (labels.isEmpty) return [];

//     // Convert camera YUV420 to RGB bytes
//     final rgbBytes = _convertYUV420toRGB(image);

//     // Prepare input as nested lists: [1][300][300][3]
//     final input = List.generate(
//       1,
//       (_) => List.generate(
//         300,
//         (_) => List.generate(300, (_) => List.filled(3, 0.0)),
//       ),
//     );

//     // Resize image manually to 300x300 and normalize [0,1]
//     for (int y = 0; y < 300; y++) {
//       for (int x = 0; x < 300; x++) {
//         final srcX = (x * image.width / 300).toInt().clamp(0, image.width - 1);
//         final srcY = (y * image.height / 300).toInt().clamp(0, image.height - 1);
//         final idx = (srcY * image.width + srcX) * 3;
//         input[0][y][x][0] = rgbBytes[idx] / 255.0;
//         input[0][y][x][1] = rgbBytes[idx + 1] / 255.0;
//         input[0][y][x][2] = rgbBytes[idx + 2] / 255.0;
//       }
//     }

//     // Prepare outputs as nested lists (no reshape())
//     final outputLocations =
//         List.generate(1, (_) => List.generate(10, (_) => List.filled(4, 0.0)));
//     final outputClasses = List.generate(1, (_) => List.filled(10, 0.0));
//     final outputScores = List.generate(1, (_) => List.filled(10, 0.0));
//     final numDetections = List.filled(1, 0.0);

//     final outputs = {
//       0: outputLocations,
//       1: outputClasses,
//       2: outputScores,
//       3: numDetections,
//     };

//     // Run inference
//     _interpreter!.runForMultipleInputs([input], outputs);

//     // Parse detections
//     List<Detection> detections = [];
//     final count = numDetections[0].toInt();

//     for (int i = 0; i < count && i < 10; i++) {
//       final score = outputScores[0][i];
//       if (score < 0.5) continue;

//       final classIndex = outputClasses[0][i].toInt();
//       String label = 'unknown';
//       if (classIndex >= 0 && classIndex < labels.length) {
//         label = labels[classIndex];
//       }

//       final loc = outputLocations[0][i];
//       // loc has format [ymin, xmin, ymax, xmax] in many SSD outputs — adapt accordingly.
//       // Here we compute center x,y and width/height as normalized values.
//       final ymin = loc[0];
//       final xmin = loc[1];
//       final ymax = loc[2];
//       final xmax = loc[3];

//       final centerX = (xmin + xmax) / 2.0;
//       final centerY = (ymin + ymax) / 2.0;
//       final w = (xmax - xmin).abs();
//       final h = (ymax - ymin).abs();

//       detections.add(Detection(label, centerX, centerY, w, h, score));
//     }

//     return detections;
//   }

//   /// Convert detections to navigation decision
//   NavigationDecision getNavigationDecision(List<Detection> objects) {
//     if (objects.isEmpty) return NavigationDecision.forward;

//     // Choose object with largest height (closest)
//     final closest = objects.reduce((a, b) => a.h > b.h ? a : b);

//     // Use center Y + half height to estimate bottom
//     final bottomEstimate = closest.y + closest.h / 2.0;

//     if (bottomEstimate > 0.75) return NavigationDecision.stop;
//     // If center is left of center -> move right (to avoid obstacle on left),
//     // if center is right of center -> move left.
//     if (closest.x < 0.4) return NavigationDecision.right;
//     if (closest.x > 0.6) return NavigationDecision.left;
//     return NavigationDecision.forward;
//   }
// }
