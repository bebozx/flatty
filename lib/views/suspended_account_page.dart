import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuspendedAccountPage extends StatelessWidget {
  const SuspendedAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 80, color: Colors.red),
            const Text("عذراً، حسابك موقوف حالياً. تواصل مع الإدارة."),
            TextButton(
              onPressed: () => Supabase.instance.client.auth.signOut(),
              child: const Text("تسجيل الخروج"),
            )
          ],
        ),
      ),
    );
  }
}
