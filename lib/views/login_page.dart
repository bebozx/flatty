import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    // 1. التحقق من إدخال البيانات
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      Get.snackbar("تنبيه", "يرجى إدخال البريد الإلكتروني وكلمة المرور",
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orangeAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. محاولة تسجيل الدخول عبر سوبابيز
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // نجح الدخول، الـ RootHandler سيتولى توجيهك
        Get.offAllNamed('/'); 
      }
    } on AuthException catch (e) {
      // 3. تعديل جوهري: إظهار رسالة الخطأ الحقيقية من سوبابيز
      // لو الباسورد غلط هيقولك "Invalid login credentials" مش "راجع الـ HR"
      Get.snackbar("خطأ في البيانات", e.message, 
          snackPosition: SnackPosition.BOTTOM, 
          backgroundColor: Colors.redAccent, 
          colorText: Colors.white,
          duration: const Duration(seconds: 5));
    } catch (e) {
      // 4. خطأ تقني غير متوقع (مثل الإنترنت)
      Get.snackbar("خطأ تقني", "حدث خطأ غير متوقع: $e",
          snackPosition: SnackPosition.BOTTOM, 
          backgroundColor: Colors.orange, 
          colorText: Colors.white);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_rounded, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "تسجيل دخول الموظفين",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              // حقل البريد الإلكتروني
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "البريد الإلكتروني",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              
              // حقل كلمة المرور
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: "كلمة المرور",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 30),
              
              // زر الدخول
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("دخول", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
