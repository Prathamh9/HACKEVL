//  lib/screens/path_guide_screen.dart
// import 'dart:async';
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// import '../services/navigation_service.dart';
// import 'package:vibration/vibration.dart';

// class PathGuideScreen extends StatefulWidget {
//   const PathGuideScreen({super.key});

//   @override
//   State<PathGuideScreen> createState() => _PathGuideScreenState();
// }

// class _PathGuideScreenState extends State<PathGuideScreen> {
//   CameraController? _controller;
//   NavigationService _navService = NavigationService();
//   FlutterTts _tts = FlutterTts();
//   bool _isProcessing = false;
//   NavigationDecision _lastDecision = NavigationDecision.unknown;
//   Timer? _speakCooldown;

//   @override
//   void initState() {
//     super.initState();
//     _initCamera();
//     _initTts();
//     _navService.loadModel();
//   }

//   void _initTts() {
//     _tts.setLanguage("en-IN");
//     _tts.setPitch(1.0);
//     _tts.setSpeechRate(0.45);
//   }

//   Future<void> _initCamera() async {
//     final cameras = await availableCameras();
//     _controller = CameraController(
//       cameras.first,
//       ResolutionPreset.medium,
//       enableAudio: false,
//     );
//     await _controller!.initialize();
//     await _controller!.startImageStream(_processCameraImage);
//     setState(() {});
//   }

//   void _processCameraImage(CameraImage image) async {
//     if (_isProcessing) return;
//     _isProcessing = true;

//     try {
//       final detections = await _navService.detectObjectsFromFrame(image);
//       final decision = _navService.getNavigationDecision(detections);

//       if (decision != _lastDecision && (_speakCooldown?.isActive ?? false) == false) {
//         _lastDecision = decision;
//         _speakDecision(decision);
//         _speakCooldown = Timer(Duration(seconds: 1), () {});
//       }
//     } catch (e) {
//       print('Error processing frame: $e');
//     } finally {
//       _isProcessing = false;
//     }
//   }

//   void _speakDecision(NavigationDecision decision) {
//     String phrase = decision.name.toUpperCase();
//     _tts.speak(phrase);
//     if (decision == NavigationDecision.stop) Vibration.vibrate(duration: 500);
//     else Vibration.vibrate(duration: 150);
//   }

//   @override
//   void dispose() {
//     _controller?.dispose();
//     _tts.stop();
//     _speakCooldown?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_controller == null || !_controller!.value.isInitialized) {
//       return Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return Scaffold(
//       appBar: AppBar(title: Text('Blind Navigation')),
//       body: CameraPreview(_controller!),
//     );
//   }
// }
