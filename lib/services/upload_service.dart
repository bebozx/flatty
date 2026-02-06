import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class UploadService {
  final _supabase = Supabase.instance.client;

  Future<void> uploadAttendance({
    required File videoFile,
    required double lat,
    required double long,
    required String type, // 'office' or 'field'
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. جلب بيانات الشركة
      final userData = await _supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      
      String companyId = userData['company_id'];
      
      // نستخدم اسم ملف ثابت لكل موظف لعمل Overwrite (استبدال) للفيديو القديم
      // وبكده الفيديو الجديد بيمسح القديم أوتوماتيكياً في الـ Storage
      String fileName = "latest_check.mp4"; 
      String storagePath = "$companyId/${user.id}/$fileName";

      // 2. رفع الفيديو مع خاصية upsert لعمل استبدال للفيديو فقط
      await _supabase.storage.from('attendance_videos').upload(
            storagePath,
            videoFile,
            fileOptions: const FileOptions(upsert: true),
          );

      // جلب رابط الفيديو (سيكون هو نفسه دائماً)
      final String videoUrl = _supabase.storage
          .from('attendance_videos')
          .getPublicUrl(storagePath);

      // 3. add new سجل جديد (بدون حذف السجلات القديمة)
      // هنا نحتفظ بالتاريخ والوقت والموقع لكل حركة حضور
      await _supabase.from('attendance').insert({
        'employee_id': user.id,
        'company_id': companyId,
        'video_path': videoUrl, 
        'location_lat': lat,
        'location_long': long,
        'type': type,
        'check_in_time': DateTime.now().toIso8601String(),
      });

      Get.snackbar("تم بنجاح", "تم تسجيل حضورك بنجاح",
          snackPosition: SnackPosition.BOTTOM, 
          backgroundColor: Colors.green, 
          colorText: Colors.white);
          
    } catch (e) {
      Get.snackbar("فشل الرفع", "حدث خطأ في النظام",
          snackPosition: SnackPosition.BOTTOM, 
          backgroundColor: Colors.red, 
          colorText: Colors.white);
    }
  }
}
