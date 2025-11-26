import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class TFLiteService {
  static const String _apiUrl = 'https://wolfvox-notedetectionmodel.hf.space';
  bool _initialized = false;

  Future<void> loadModel() async {
    // No local model to load - we use the API
    // Just mark as initialized
    _initialized = true;
    print(' API service initialized | endpoint=$_apiUrl');
  }

  Future<String> runModelOnImage(File imageFile, {bool debug = false}) async {
    if (!_initialized) {
      throw Exception('Service not initialized. Call loadModel() first.');
    }

    try {
      // Read and compress image to reduce upload size
      final originalBytes = await imageFile.readAsBytes();
      print(' Original image size: ${originalBytes.length} bytes');
      
      // Decode, resize, and re-encode as JPEG with compression
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) {
        return 'Error: Could not decode image';
      }
      
      // Resize to max 640px on longest side (model input size)
      final maxSize = 640;
      img.Image resized;
      if (decoded.width > decoded.height) {
        resized = decoded.width > maxSize 
            ? img.copyResize(decoded, width: maxSize)
            : decoded;
      } else {
        resized = decoded.height > maxSize 
            ? img.copyResize(decoded, height: maxSize)
            : decoded;
      }
      
      // Encode as JPEG with 85% quality
      final compressedBytes = img.encodeJpg(resized, quality: 85);
      print(' Compressed image size: ${compressedBytes.length} bytes');
      
      final base64Image = base64Encode(compressedBytes);
      final dataUri = 'data:image/jpeg;base64,$base64Image';

      print(' Sending image to API (${compressedBytes.length} bytes)');

      // Gradio 6.x uses /gradio_api/call/{api_name} with SSE
      // Step 1: Submit the job
      final submitResponse = await http.post(
        Uri.parse('$_apiUrl/gradio_api/call/predict'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': [
            {
              'url': dataUri,
              'meta': {'_type': 'gradio.FileData'}
            }
          ],
        }),
      ).timeout(const Duration(seconds: 30));
      
      print(' Submit response: ${submitResponse.statusCode} - ${submitResponse.body}');
      
      if (submitResponse.statusCode != 200) {
        return 'API error: ${submitResponse.statusCode}';
      }
      
      // Get the event_id from response
      final submitResult = jsonDecode(submitResponse.body);
      final eventId = submitResult['event_id'];
      
      if (eventId == null) {
        print(' No event_id in response');
        return 'Detection failed';
      }
      
      // Step 2: Get the result using SSE endpoint
      print(' Fetching result for event_id: $eventId');
      final resultResponse = await http.get(
        Uri.parse('$_apiUrl/gradio_api/call/predict/$eventId'),
      ).timeout(const Duration(seconds: 60));
      
      print(' Result response: ${resultResponse.statusCode}');
      print(' Result body: ${resultResponse.body}');
      
      // Parse SSE response - look for "data:" lines
      final lines = resultResponse.body.split('\n');
      String? jsonData;
      for (final line in lines) {
        if (line.startsWith('data:')) {
          jsonData = line.substring(5).trim();
        }
      }
      
      if (jsonData == null || jsonData.isEmpty) {
        return 'No result from API';
      }
      
      final result = jsonDecode(jsonData);
      print(' Parsed result: $result');

      // Parse the detection result and extract currency info
      return _parseDetectionResult(result);
    } catch (e) {
      print(' API call failed: $e');
      return 'Error detecting currency';
    }
  }

  // Parse the API response and extract currency denomination
  String _parseDetectionResult(dynamic result) {
    try {
      // Gradio returns [data] array in result
      if (result is List && result.isNotEmpty) {
        final prediction = result[0];
        
        // If it's a Map with detections
        if (prediction is Map) {
          // Check for detections array (YOLO format)
          if (prediction['detections'] != null && prediction['detections'] is List) {
            final detections = prediction['detections'] as List;
            if (detections.isNotEmpty) {
              // Get the detection with highest confidence
              var bestDetection = detections[0];
              double bestConf = 0.0;
              
              for (final det in detections) {
                final conf = (det['confidence'] ?? det['score'] ?? 0).toDouble();
                if (conf > bestConf) {
                  bestConf = conf;
                  bestDetection = det;
                }
              }
              
              final className = bestDetection['class_name'] ?? 
                               bestDetection['class'] ?? 
                               bestDetection['label'] ?? 
                               bestDetection['name'] ?? '';
              print(' Best detection: $bestDetection');
              print(' Class name: $className, confidence: $bestConf');
              return _extractCurrencyValue(className.toString());
            }
          }
          
          // Check for direct label/class field
          if (prediction['label'] != null) {
            return _extractCurrencyValue(prediction['label'].toString());
          }
          if (prediction['class'] != null) {
            return _extractCurrencyValue(prediction['class'].toString());
          }
          if (prediction['prediction'] != null) {
            return _extractCurrencyValue(prediction['prediction'].toString());
          }
          
          // Check for results array
          if (prediction['results'] != null && prediction['results'] is List) {
            final results = prediction['results'] as List;
            if (results.isNotEmpty) {
              final first = results[0];
              final label = first['label'] ?? first['class'] ?? first['name'] ?? '';
              return _extractCurrencyValue(label.toString());
            }
          }
          
          // Return the whole thing formatted if nothing specific found
          return _extractCurrencyValue(prediction.toString());
        }
        
        // If it's just a string
        if (prediction is String) {
          return _extractCurrencyValue(prediction);
        }
        
        return _extractCurrencyValue(prediction.toString());
      }
      
      // Handle Map result directly
      if (result is Map) {
        if (result['label'] != null) {
          return _extractCurrencyValue(result['label'].toString());
        }
        return _extractCurrencyValue(result.toString());
      }
      
      return 'No currency detected';
    } catch (e) {
      print(' Error parsing result: $e');
      return 'Detection error';
    }
  }

  // Extract just the currency value - return only the number
  String _extractCurrencyValue(String raw) {
    print(' Extracting currency from: $raw');
    
    // Common patterns: "100_rupees", "Rs100", "100 Rupees", "₹100", "10-rupee"
    final patterns = [
      RegExp(r'(\d+)\s*[_-]?\s*rupees?', caseSensitive: false),
      RegExp(r'Rs\.?\s*(\d+)', caseSensitive: false),
      RegExp(r'₹\s*(\d+)'),
      RegExp(r'(\d+)\s*Rs', caseSensitive: false),
      RegExp(r'INR\s*(\d+)', caseSensitive: false),
      RegExp(r'(\d+)\s*INR', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(raw);
      if (match != null) {
        final value = match.group(1);
        if (value != null) {
          print(' Extracted denomination: $value');
          return value; // Just return the number
        }
      }
    }
    
    // Check for just a number (10, 20, 50, 100, 200, 500, 2000)
    final validDenominations = ['2000', '500', '200', '100', '50', '20', '10'];
    for (final denom in validDenominations) {
      if (raw.contains(denom)) {
        print(' Found denomination: $denom');
        return denom; // Just return the number
      }
    }
    
    // Fallback - return cleaned string
    String cleaned = raw
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'[{}"\[\]]'), '')
        .trim();
    
    if (cleaned.isEmpty || cleaned == 'null') {
      return 'unknown';
    }
    
    return cleaned;
  }

  void close() {
    // Nothing to close for API-based service
    _initialized = false;
  }
}