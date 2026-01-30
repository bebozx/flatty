import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String SUPABASE_URL = 'https://fdmcuadexssqawrmhoqw.supabase.co';
const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkbWN1YWRleHNzcWF3cm1ob3F3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MTMwMjUsImV4cCI6MjA4NTE4OTAyNX0.jMgXBusEhmqPK_ogGzCvgBT4YfLiCEc9RH1hRxjzOqQ';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);
  runApp(const PizzacoClientApp());
}

class PizzacoClientApp extends StatelessWidget {
  const PizzacoClientApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFF5722),
        fontFamily: 'Cairo',
      ),
      home: const SplashScreen(),
    );
  }
}

// 1. Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const ClientHomePage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF5722),
      body: Center(
        child: Text(
          "PIZZACO",
          style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4),
        ),
      ),
    );
  }
}

// 2. Main Page
class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});
  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  bool _loading = true;
  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  String _selectedCatId = '';
  int _prodIdx = 0;
  final Map<String, dynamic> _cart = {};
  final Map<String, String> _selectedVariant = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final cats = await Supabase.instance.client.from('categories').select().eq('is_active', true).order('order');
      _categories = cats as List;
      if (_categories.isNotEmpty) _selectedCatId = _categories.first['id'].toString();

      final prods = await Supabase.instance.client.from('products').select().eq('is_active', true).order('order');
      final imgs = await Supabase.instance.client.from('product_images').select();
      final vars = await Supabase.instance.client.from('product_variants').select().eq('is_active', true);

      _products = (prods as List).map((p) {
        p['images'] = (imgs as List).where((i) => i['product_id'] == p['id']).map((i) => i['image_url']).toList();
        p['variants'] = (vars as List).where((v) => v['product_id'] == p['id']).toList();
        if (p['variants'].isNotEmpty) _selectedVariant[p['id'].toString()] = p['variants'].first['key'];
        return p;
      }).toList();
      setState(() => _loading = false);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  double get _cartTotal => _cart.values.fold(0, (sum, item) => sum + (item['v']['price'] * item['qty']));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    // فلترة المنتجات بناءً على القسم المختار
    final filtered = _products.where((p) => p['category_id'].toString() == _selectedCatId).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        // زر الاتصال على اليسار
        leading: IconButton(
          icon: const Icon(Icons.phone, color: Colors.blue), 
          onPressed: () => launchUrl(Uri.parse('tel:0123456789'))
        ),
        // اسم المطعم في المنتصف بالإنجليزية وبدون إضافات
        title: const Text(
          'PIZZACO', 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            letterSpacing: 2, 
            color: Colors.black
          )
        ),
        centerTitle: true,
        // جرس الإشعارات على اليمين
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.amber), 
            onPressed: _showNotifications
          ),
        ],
      ),
      body: Column(
        children: [
          // قائمة الأقسام (بيتزا، مقبلات، الخ)
          _buildCatList(),
          // منطقة عرض المنتجات (السلايدر)
          Expanded(
            child: filtered.isEmpty 
              ? const Center(child: Text("لا توجد منتجات في هذا القسم")) 
              : _buildSlider(filtered)
          ),
        ],
      ),
      // بار السلة السفلي يظهر فقط عند وجود طلبات
      bottomNavigationBar: _cart.isNotEmpty ? _buildCartBar() : null,
    );
  }
  Widget _buildCatList() => SizedBox(
    height: 60,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _categories.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ChoiceChip(
          label: Text(_categories[i]['name_ar']),
          selected: _selectedCatId == _categories[i]['id'].toString(),
          onSelected: (s) => setState(() { _selectedCatId = _categories[i]['id'].toString(); _prodIdx = 0; }),
          selectedColor: const Color(0xFFFF5722),
          labelStyle: TextStyle(color: _selectedCatId == _categories[i]['id'].toString() ? Colors.white : Colors.black),
        ),
      ),
    ),
  );

  Widget _buildSlider(List<dynamic> prods) {
  final p = prods[_prodIdx];
  return Stack(
    children: [
      Column(
        children: [
          // الصورة بارتفاع ثابت ومحمي
          Container(
            height: 250,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(image: NetworkImage(p['images'].isNotEmpty ? p['images'].first : 'https://via.placeholder.com/400'), fit: BoxFit.cover),
            ),
          ),
          Text(p['name_ar'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(p['description_ar'] ?? '', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          // جعل الأحجام قابلة للتمرير أفقياً وإضافة تلقائية
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: p['variants'].map<Widget>((v) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  avatar: _selectedVariant[p['id'].toString()] == v['key'] ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  label: Text('${v['name_ar']} (${v['price']} ج)'),
                  selected: _selectedVariant[p['id'].toString()] == v['key'],
                  onSelected: (s) {
                    setState(() {
                      _selectedVariant[p['id'].toString()] = v['key'];
                      // إضافة تلقائية للسلة عند الاختيار
                      _cart["${p['id']}-${v['key']}"] = {'p': p, 'v': v, 'qty': 1};
                    });
                  },
                ),
              )).toList(),
            ),
          ),
        ],
      ),
      if (_prodIdx > 0) Positioned(left: 10, top: 110, child: _navBtn(Icons.arrow_back_ios, () => setState(() => _prodIdx--))),
      if (_prodIdx < prods.length - 1) Positioned(right: 10, top: 110, child: _navBtn(Icons.arrow_forward_ios, () => setState(() => _prodIdx++))),
    ],
  );
}

  Widget _navBtn(IconData icon, VoidCallback t) => CircleAvatar(backgroundColor: Colors.grey[200], child: IconButton(icon: Icon(icon, size: 18, color: Colors.black), onPressed: t));

  Widget _buildCartBar() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('إجمالي السلة: ${_cartTotal.toStringAsFixed(0)} ج م', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ElevatedButton(onPressed: _openCheckout, child: const Text("تأكيد الطلب")),
      ],
    ),
  );

void _openCheckout() async {
    final prefs = await SharedPreferences.getInstance();
    final nameC = TextEditingController(text: prefs.getString('cust_name'));
    final phoneC = TextEditingController(text: prefs.getString('cust_phone'));
    final addrC = TextEditingController(text: prefs.getString('cust_address'));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (c) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(c).viewInsets.bottom, 
          left: 20, 
          right: 20, 
          top: 20
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "تفاصيل طلبك", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 10),
              // عرض محتويات السلة
              ..._cart.values.map((it) => ListTile(
                leading: const Icon(Icons.shopping_basket_outlined, color: Color(0xFFFF5722)),
                title: Text("${it['p']['name_ar']} - ${it['v']['name_ar']}"),
                trailing: Text("x${it['qty']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
              const Divider(height: 30),
              TextField(
                controller: nameC, 
                decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder())
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneC, 
                decoration: const InputDecoration(labelText: 'الموبايل', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addrC, 
                decoration: const InputDecoration(labelText: 'العنوان بالتفصيل', border: OutlineInputBorder()),
                maxLines: 2
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: () async {
                  if (nameC.text.isEmpty || phoneC.text.isEmpty || addrC.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("برجاء ملء جميع البيانات"))
                    );
                    return;
                  }

                  try {
                    // 1. إظهار لودينج عشان اليوزر يحس إن فيه حاجة بتحصل
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    // 2. إرسال الطلب لـ سوبابيز
                    await Supabase.instance.client.from('orders').insert({
                      'customer_snapshot': {
                        'name': nameC.text, 
                        'phone': phoneC.text, 
                        'address': addrC.text
                      },
                      'total': _cartTotal,
                      'status': 'جديد'
                    });

                    // 3. حفظ البيانات محلياً للمرة الجاية
                    await prefs.setString('cust_phone', phoneC.text);
                    await prefs.setString('cust_name', nameC.text);
                    await prefs.setString('cust_address', addrC.text);

                    // 4. قفل اللودينج وقفل الشيت وتصفير السلة
                    if (mounted) {
                      Navigator.pop(context); // قفل الـ Loading Dialog
                      Navigator.pop(context); // قفل الـ BottomSheet
                      setState(() => _cart.clear());
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.green,
                          content: Text("✅ تم إرسال طلبك بنجاح! تابع حالة الطلب من الجرس")
                        )
                      );
                    }
                  } catch (e) {
                    // قفل اللودينج لو حصل خطأ
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("خطأ في الاتصال: $e"))
                    );
                  }
                },
                child: const Text("تأكيد وإرسال الطلب الآن", style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('cust_phone');
    if (phone == null) return;
    
    showModalBottomSheet(
      context: context,
      builder: (c) => StreamBuilder(
        stream: Supabase.instance.client.from('orders').stream(primaryKey: ['id']),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final active = snap.data!.where((o) => o['customer_snapshot']['phone'] == phone && o['status'] != 'تم التسليم').toList();
          return active.isEmpty 
            ? const Center(child: Text("لا توجد تحديثات حالية"))
            : ListView.builder(
                itemCount: active.length,
                itemBuilder: (c, i) => ListTile(
                  leading: const Icon(Icons.flutter_dash, color: Color(0xFFFF5722)),
                  title: Text("طلب #${active[i]['id'].toString().substring(0,5)}"),
                  subtitle: Text("الحالة: ${active[i]['status']}"),
                ),
              );
        },
      ),
    );
  }
}
