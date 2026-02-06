import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'dart:io';
import '../services/upload_service.dart';

class FieldAttendancePage extends StatefulWidget {
  const FieldAttendancePage({super.key});

  @override
  State<FieldAttendancePage> createState() => _FieldAttendancePageState();
}

class _FieldAttendancePageState extends State<FieldAttendancePage> {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    _controller = CameraController(front, ResolutionPreset.medium);
    await _controller!.initialize();
    if (mounted) setState(() => _isInitializing = false);
  }

  // منطق المندوب: تصوير مباشر بدون فحص مسافة
  Future<void> _startFieldProcess() async {
    try {
      setState(() => _isRecording = true);
      
      // بدء تسجيل الفيديو
      await _controller!.startVideoRecording();
      
      // انتظار 6 ثوانٍ
      await Future.delayed(const Duration(seconds: 6));
      
      // إيقاف التسجيل وجلب الملف
      XFile videoFile = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);

      // جلب الموقع الحالي (للتسجيل فقط وليس للمنع)
      Position position = await Geolocator.getCurrentPosition();

      // استدعاء خدمة الرفع التي صممناها
      await UploadService().uploadAttendance(
        videoFile: File(videoFile.path),
        lat: position.latitude,
        long: position.longitude,
        type: 'field', // النوع هنا ميداني
      );

    } catch (e) {
      setState(() => _isRecording = false);
      Get.snackbar("خطأ", "فشل في عملية التسجيل أو الرفع");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text("متابعة المناديب (ميداني)")),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("سجل فيديو 6 ثوانٍ من موقعك الحالي", 
              style: TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: _isRecording ? null : _startFieldProcess,
              icon: Icon(_isRecording ? Icons.cloud_upload : Icons.location_on),
              label: Text(_isRecording ? "جاري الرفع..." : "إرسال الموقع الحالي"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.orange, // لون مميز للمناديب
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
