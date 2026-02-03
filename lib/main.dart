import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MaterialApp(home: TestScreen()));

class TestScreen extends StatelessWidget {
  // هنا بنحط رابط فيرسل اللي أنت جربته وطلع "Method Not Allowed"
  final String vercelUrl = 'https://رابط-مشروعك-بتاع-فيرسل.vercel.app/api/verify';

  Future<void> checkConnection() async {
    try {
      // بنبعت طلب POST للسيرفر
      final response = await http.post(Uri.parse(vercelUrl));
      print("Server Response: ${response.body}");
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Identity Verifier MVP")),
      body: Center(
        child: ElevatedButton(
          onPressed: checkConnection,
          child: Text("اختبار الاتصال بالسيرفر"),
        ),
      ),
    );
  }
}
