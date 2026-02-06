import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // لتنسيق الوقت والتاريخ

class AttendanceReportPage extends StatelessWidget {
  const AttendanceReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text("سجل حضوري"),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // استخدام Stream لجعل الصفحة "Real-time" كما اتفقنا
        stream: Supabase.instance.client
            .from('attendance')
            .stream(primaryKey: ['id'])
            .eq('employee_id', userId)
            .order('check_in_time', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("لا يوجد سجلات حضور حتى الآن"),
            );
          }

          final reports = snapshot.data!;

          return ListView.builder(
            itemCount: reports.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final item = reports[index];
              final DateTime date = DateTime.parse(item['check_in_time']).toLocal();
              
              // تحديد الأيقونة واللون بناءً على النوع
              bool isOffice = item['type'] == 'office';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOffice ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    child: Icon(
                      isOffice ? Icons.business : Icons.map,
                      color: isOffice ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(
                    DateFormat('EEEE, d MMMM').format(date), // اسم اليوم والتاريخ
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("الوقت: ${DateFormat('hh:mm a').format(date)}"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isOffice ? "مكتبي" : "ميداني",
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
