import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  
  // البحث عن الكاميرا الأمامية بدقة
  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first, // لو ملقاش أمامية يفتح المتاحة
  );

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: IdentityApp(camera: frontCamera),
  ));
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
  String serverResponse = "في انتظار ضغط الزر...";
  
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera, 
      ResolutionPreset.medium,
      enableAudio: false, // مش محتاجين صوت عشان السرعة
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> checkServer() async {
    setState(() => serverResponse = "جاري الاتصال...");
    try {
      final url = Uri.parse('https://identity-verifier-backend.vercel.app/api/verify');
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
      );
      setState(() => serverResponse = res.body);
    } catch (e) {
      setState(() => serverResponse = "خطأ اتصال: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Identity Verifier MVP")),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black87,
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  "رد السيرفر: $serverResponse",
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: checkServer,
                  child: const Text("اختبار السيرفر والربط"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
