import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

// تفعيل الاستيراد الآن لأن الملفات أصبحت موجودة في مشروعك
import 'views/login_page.dart';
import 'views/main_navigation.dart';
import 'views/suspended_account_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة سوبابيز ببيانات مشروعك الفعلية
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
        fontFamily: 'Arial',
      ),
      // الدخول عبر معالج الجلسات
      home: const RootHandler(),
    );
  }
}

// 1. استبدل كلاس RootHandler بهذا ليكون أكثر استجابة للحالة
class RootHandler extends StatelessWidget {
  const RootHandler({super.key});

  @override
  Widget build(BuildContext context) {
    // استخدام StreamBuilder لمراقبة حالة التسجيل لحظة بلحظة
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session == null) {
          return LoginPage();
        } else {
          return const AuthChecker();
        }
      },
    );
  }
}

// 2. استبدل كلاس AuthChecker بهذا (الإصدار المقاوم للأخطاء)
class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  Future<bool> isUserActive() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      // استخدام maybeSingle بدل single لمنع الانهيار عند التأخير
      final data = await Supabase.instance.client
          .from('profiles')
          .select('status')
          .eq('id', user.id)
          .maybeSingle(); 

      if (data == null) {
        debugPrint("User profile not found for ID: ${user.id}");
        return false;
      }

      return data['status'] == 'active';
    } catch (e) {
      debugPrint("AuthChecker Error: $e");
      return false;
    }
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
        
        // التحقق من الحالة بمرونة أكبر
        if (snapshot.hasData && snapshot.data == true) {
          return MainNavigation();
        } else {
          return SuspendedAccountPage();
        }
      },
    );
  }
}

 
