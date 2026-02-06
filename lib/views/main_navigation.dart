import 'package:flutter/material.dart';
import 'office_attendance_page.dart';
import 'field_attendance_page.dart';
import 'attendance_report_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // 1. تحديد الصفحة الحالية
  int _selectedIndex = 0;

  // 2. قائمة الصفحات التي برمجناها سابقاً
  final List<Widget> _pages = [
     OfficeAttendancePage(),
     FieldAttendancePage(),
     AttendanceReportPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack يحافظ على "حالة" الصفحات (مثلاً لا يعيد تشغيل الكاميرا كلما تنقلت)
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      
      // البار السفلي بنظام Material 3 الحديث
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.business, color: Colors.green),
            icon: Icon(Icons.business_outlined),
            label: 'المكتب',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.location_on, color: Colors.orange),
            icon: Icon(Icons.location_on_outlined),
            label: 'الميدان',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.history, color: Colors.blue),
            icon: Icon(Icons.history_outlined),
            label: 'تقاريري',
          ),
        ],
      ),
    );
  }
}
