import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

// استيراد الصفحات (سنقوم بإنشائها في الخطوات القادمة)
// import 'views/login_page.dart';
// import 'views/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة سوبابيز - استبدل القيم ببيانات مشروعك
  await Supabase.initialize(
    url: 'https://phxrbhoasozlcowqkbdm.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBoeHJiaG9hc296bGNvd3FrYmRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzODc3MzQsImV4cCI6MjA4NTk2MzczNH0.0GIhxiqmZk7I5ETEg88j77SsebQa3pDg3sKcMp3Vdrc',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Attendance App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        fontFamily: 'Arial', // يمكنك تغيير الخط لاحقاً
      ),
      // نقطة البداية تعتمد على فحص الجلسة
      home: const RootHandler(),
    );
  }
}

// كود فحص حالة الدخول (Authentication Handler)
class RootHandler extends StatelessWidget {
  const RootHandler({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // replace بصفحة تسجيل الدخول إذا لم يكن هناك جلسة
      return const LoginPage(); 
    } else {
      // فحص هل الحساب موقوف أم لا قبل الدخول
      return const AuthChecker();
    }
  }
}

// كود التأكد من أن الموظف نشط (Status Checker)
class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  Future<bool> isUserActive() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final data = await Supabase.instance.client
        .from('profiles')
        .select('status')
        .eq('id', userId)
        .single();
    
    return data['status'] == 'active';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: isUserActive(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasData && snapshot.data == true) {
          // الموظف نشط -> اذهب للرئيسية
          return const MainNavigation(); 
        } else {
          // الموظف موقوف -> اعرض رسالة تنبيه واعمل تسجيل خروج
          return const SuspendedAccountPage();
        }
      },
    );
  }
}
