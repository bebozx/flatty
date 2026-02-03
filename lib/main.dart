import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: IdentityApp(camera: front)));
}

class IdentityApp extends StatefulWidget {
  final CameraDescription camera;
  const IdentityApp({super.key, required this.camera});
  @override
  State<IdentityApp> createState() => _IdentityAppState();
}

class _IdentityAppState extends State<IdentityApp> {
  late CameraController _controller;
  bool _isProcessing = false;
  String _statusMessage = "جاري تشغيل الذكاء الاصطناعي...";
  final FaceDetector _faceDetector = FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast));

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.low, enableAudio: false);
    _controller.initialize().then((_) {
      _controller.startImageStream((image) => _processImage(image));
    });
  }

  void _processImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final faces = await _faceDetector.processImage(
        InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotation.rotation270deg, // الزاوية الصحيحة للكاميرا الأمامية
            format: InputImageFormat.nv21, // التنسيق القياسي لـ أندرويد
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _statusMessage = faces.isNotEmpty ? "✅ تم اكتشاف الوجه" : "❌ قرب الموبايل من وشك";
        });
      }
    } catch (e) {
      // لو فيه خطأ يظهر هنا بدل ما يفضل معلق
      setState(() => _statusMessage = "خطأ في المعالجة");
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
          Center(child: CameraPreview(_controller)),
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20, backgroundColor: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
