import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// تأكد من صحة المفتاح 100% من لوحة تحكم سوبابيز
const String SUPABASE_URL = 'https://fdmcuadexssqawrmhoqw.supabase.co';
const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkbWN1YWRleHNzcWF3cm1ob3F3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MTMwMjUsImV4cCI6MjA4NTE4OTAyNX0.jMgXBusEhmqPK_ogGzCvgBT4YfLiCEc9RH1hRxjzOqQ';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);
  } catch (e) {
    debugPrint("Init Error: $e");
  }
  runApp(const PizzacoClientApp());
}

SupabaseClient get supa => Supabase.instance.client;

class PizzacoClientApp extends StatelessWidget {
  const PizzacoClientApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بيتزاكو',
      debugShowCheckedModeBanner: false,
      // ألوان عصرية (أورانج مع أزرق داكن)
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5722),
          primary: const Color(0xFFFF5722),
          secondary: const Color(0密1A237E),
        ),
        fontFamily: 'Cairo',
      ),
      home: const ClientHomePage(),
    );
  }
}

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});
  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  bool _loading = true;
  String? _error;
  // باقي المتغيرات (categories, products, etc.)

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() { _loading = true; _error = null; });
    try {
      // الـ timeout عشان لو الشبكة ضعيفة ما يعلقش
      await Future.delayed(const Duration(seconds: 1)); 
      
      // جلب البيانات مع معالجة الأخطاء
      final cats = await supa.from('categories').select().eq('is_active', true).order('order').timeout(const Duration(seconds: 15));
      // ... تكملة جلب باقي البيانات كما في الكود السابق
      
      setState(() => _loading = false);
    } catch (e) {
      setState(() { 
        _error = "تأكد من اتصالك بالإنترنت"; 
        _loading = false; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading 
        ? _buildModernLoading() 
        : _error != null 
          ? _buildErrorView()
          : _buildMainContent(), // المحتوى الأصلي
    );
  }

  // لودينج بتصميم عصري وألوان جذابة بدل البني
  Widget _buildModernLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60, height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5722)),
              backgroundColor: Color(0xFFFFCCBC),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "بنسخّن الفرن... 🍕",
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: Colors.grey[800]
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(_error!),
          TextButton(onPressed: _bootstrap, child: const Text("إعادة المحاولة"))
        ],
      ),
    );
  }
  
  // دالة _buildMainContent تحتوي على الـ Column والـ Slider اللي عملناهم
  Widget _buildMainContent() {
    return const Text("المحتوى هنا"); // ضع هنا كود الـ UI المطور
  }
}
