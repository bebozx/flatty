import 'dart:io'; // حل مشكلة خطأ File
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

// حل مشكلة خطأ UploadService (تأكد من صحة المسار)
import '../services/upload_service.dart';

class OfficeAttendancePage extends StatefulWidget {
  const OfficeAttendancePage({super.key});

  @override
  State<OfficeAttendancePage> createState() => _OfficeAttendancePageState();
}

class _OfficeAttendancePageState extends State<OfficeAttendancePage> {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  // 1. تشغيل الكاميرا الأمامية
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    
    _controller = CameraController(front, ResolutionPreset.medium);
    await _controller!.initialize();
    
    setState(() => _isInitializing = false);
  }

  // 2. التحقق من الموقع الجغرافي (GPS)
  Future<bool> _checkLocation() async {
    // جلب موقع الموظف الحالي
    Position position = await Geolocator.getCurrentPosition();
    
    // جلب إحداثيات الشركة من جدول البروفايل (عبر الـ Join مع الشركات)
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final userData = await Supabase.instance.client
        .from('profiles')
        .select('companies(location_lat, location_long)')
        .eq('id', userId)
        .single();

    double officeLat = userData['companies']['location_lat'];
    double officeLong = userData['companies']['location_long'];

    // حساب المسافة بين الموظف والشركة (بالمتر)
    double distance = Geolocator.distanceBetween(
      position.latitude, position.longitude, officeLat, officeLong
    );

    return distance < 100; // السماح بـ 100 متر حول الشركة
  }

  // 3. منطق تسجيل الفيديو لمدة 6 ثوانٍ
  Future<void> _startAttendanceProcess() async {
    // أ- التأكد من الموقع أولاً
    bool isInOffice = await _checkLocation();
    if (!isInOffice) {
      Get.snackbar("خطأ في الموقع", "أنت خارج نطاق الشركة حالياً");
      return;
    }

    // ب- بدء التسجيل
    setState(() => _isRecording = true);
    await _controller!.startVideoRecording();

    // ج- الانتظار 6 ثوانٍ ثم الإيقاف تلقائياً
    await Future.delayed(const Duration(seconds: 6));
    XFile videoFile = await _controller!.stopVideoRecording();
    setState(() => _isRecording = false);

    // د- الانتقال لعملية الرفع (سنبرمجها في الخطوة القادمة)
    _uploadAttendance(videoFile);
  }

  // استدعاء الخدمة داخل الصفحة
Future<void> _uploadAttendance(XFile file) async {
  final position = await Geolocator.getCurrentPosition();
  
  // تشغيل خدمة الرفع
  await UploadService().uploadAttendance(
    videoFile: File(file.path),
    lat: position.latitude,
    long: position.longitude,
    type: 'office',
  );
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
      appBar: AppBar(title: const Text("حضور الموظفين")),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: _isRecording ? null : _startAttendanceProcess,
              icon: Icon(_isRecording ? Icons.timer : Icons.videocam),
              label: Text(_isRecording ? "جاري التسجيل..." : "تسجيل حضور (6 ثوانٍ)"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: _isRecording ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
