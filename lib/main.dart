import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MaterialApp(home: IdentityApp(camera: cameras.first)));
}

class IdentityApp extends StatefulWidget {
  final CameraDescription camera;
  IdentityApp({required this.camera});

  @override
  _IdentityAppState createState() => _IdentityAppState();
}

class _IdentityAppState extends State<IdentityApp> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  String serverResponse = "لم يتم الاتصال بعد";

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
  }

  Future<void> checkServer() async {
    try {
      // ركز هنا: شيل أي / في آخر الرابط قبل api
      var url = Uri.parse('https://identity-verifier-backend.vercel.app/api/verify'); 
      
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
      );

      setState(() => serverResponse = res.body);
    } catch (e) {
      setState(() => serverResponse = "Connection Error: $e");
    }
  }
  


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("MVP Identity Step 1")),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("رد السيرفر: $serverResponse", style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(onPressed: checkServer, child: Text("اختبار السيرفر")),
        ],
      ),
    );
  }
}
