import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: IdentityApp(camera: frontCamera)));
}

class IdentityApp extends StatefulWidget {
  final CameraDescription camera;
  const IdentityApp({super.key, required this.camera});
  @override
  State<IdentityApp> createState() => _IdentityAppState();
}

class _IdentityAppState extends State<IdentityApp> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isProcessing = false;
  String _statusMessage = "وجه الكاميرا لوجهك...";
  
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast),
  );

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.low, enableAudio: false);
    _initializeControllerFuture = _controller.initialize().then((_) {
      // بدء بث الصور بمجرد تشغيل الكاميرا
      _controller.startImageStream(_processCameraImage);
    });
  }

  // دالة معالجة الصور القادمة من البث
  void _processCameraImage(CameraImage image) async {
    if (_isProcessing) return; // لو السيرفر مشغول لا ترسل صورة جديدة
    _isProcessing = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg, // مناسب لأغلب الكاميرات الأمامية
          format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          if (faces.isNotEmpty) {
            _statusMessage = "✅ تم اكتشاف وجهك (عدد: ${faces.length})";
          } else {
            _statusMessage = "❌ لا يوجد وجه.. قرب الموبايل";
          }
        });
      }
    } catch (e) {
      debugPrint("Error processing image: $e");
    }
    _isProcessing = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return Center(child: CameraPreview(_controller));
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
          Positioned(
            bottom: 50, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
