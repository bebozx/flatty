import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

// تفعيل الاستيراد
import 'views/login_page.dart';
import 'views/main_navigation.dart';
import 'views/suspended_account_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const RootHandler(),
    );
  }
}

class RootHandler extends StatelessWidget {
  const RootHandler({super.key});

  @override
  Widget build(BuildContext context) {
    // مراقبة حالة المستخدم لحظياً
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.data?.session;
        return session == null ? LoginPage() : const AuthChecker();
      },
    );
  }
}

class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  Future<String> checkUserStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return 'no_user';

      final data = await Supabase.instance.client
          .from('profiles')
          .select('status')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return 'no_profile';
      return data['status'] ?? 'inactive';
    } catch (e) {
      debugPrint("خطأ في الاتصال بالقاعدة: $e");
      return 'error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: checkUserStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.data == 'active') {
          return MainNavigation();
        } else {
          // هنا سيعرض الصفحة الحمراء، ولو تابعت الـ Debug Console ستعرف السبب (no_profile أو error)
          return SuspendedAccountPage();
        }
      },
    );
  }
}
