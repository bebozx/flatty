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
  List<dynamic> _myOrders = []; 
  StreamSubscription? _orderSubscription;
  @override
  void initState() {
    super.initState();
    _fetchData();
    _setupOrderRealtime(); // ضيف السطر ده هنا
  }

    
  void _setupOrderRealtime() {
    _orderSubscription = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen((List<Map<String, dynamic>> data) {
      if (mounted) {
        setState(() {
          _myOrders = data;
        });
      }
    });
  }

@override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  
 Widget _buildQtyStepper(dynamic p, dynamic v, String key) {
    int qty = _cart[key]?['qty'] ?? 0;
    return Container(
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: qty > 0 ? () => setState(() {
            if (qty == 1) _cart.remove(key); else _cart[key]['qty']--;
          }) : null),
          Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF5722)), onPressed: () => setState(() {
            if (qty == 0) _cart[key] = {'p': p, 'v': v, 'qty': 1}; else _cart[key]['qty']++;
          })),
        ],
      ),
    );
  }
  
Future<void> _fetchData() async {
    try {
      final client = Supabase.instance.client;
      
      final catsData = await client.from('categories').select().eq('is_active', true).order('order');
      _categories = catsData as List;

      final prodsData = await client.from('products').select().eq('is_active', true).order('order');
      final imgsData = await client.from('product_images').select();
      final varsData = await client.from('product_variants').select().eq('is_active', true);

      _products = (prodsData as List).map((p) {
        p['images'] = (imgsData as List).where((i) => i['product_id'] == p['id']).map((i) => i['image_url']).toList();
        p['variants'] = (varsData as List).where((v) => v['product_id'] == p['id']).toList();
        if (p['variants'].isNotEmpty) _selectedVariant[p['id'].toString()] = p['variants'].first['key'];
        return p;
      }).toList();

      if (_categories.isNotEmpty) {
        _selectedCatId = _categories.first['id'].toString();
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  double get _cartTotal => _cart.values.fold(0, (sum, item) => sum + (item['v']['price'] * item['qty']));
  
 @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final filtered = _products.where((p) => p['category_id'].toString() == _selectedCatId).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.phone, color: Colors.blue), onPressed: () => launchUrl(Uri.parse('tel:0123456789'))),
        title: const Text('PIZZACO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
       actions: [
  Stack(
    alignment: Alignment.center,
    children: [
      IconButton(
        icon: const Icon(Icons.notifications_active, color: Colors.amber),
        onPressed: _showNotifications, // دي الدالة اللي بتعرض القائمة
      ),
      // لو فيه طلبات حالتها مش delivered يظهر الرقم
      if (_myOrders.where((o) => o['status'] != 'delivered').isNotEmpty)
        Positioned(
          right: 8,
          top: 8,
          child: CircleAvatar(
            radius: 8,
            backgroundColor: Colors.red,
            child: Text(
              '${_myOrders.where((o) => o['status'] != 'delivered').length}',
              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
    ],
  ),
],
      ),
      body: Column(
        children: [
          _buildCatList(),
          Expanded(
            child: filtered.isEmpty 
              ? const Center(child: Text("لا توجد منتجات")) 
              : SingleChildScrollView( // أضفنا سكرول للمحتوى كله عشان نضمن مفيش تداخل
                  padding: const EdgeInsets.only(bottom: 100), // مسافة أمان للبار السفلي
                  child: _buildSlider(filtered),
                ),
          ),
        ],
      ),
      extendBody: true, // بيخلي المحتوى يفرش ورا البار لكن بمسافة أمان
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
  final String currentVariantKey = _selectedVariant[p['id'].toString()] ?? '';
  final String cartKey = "${p['id']}-$currentVariantKey";
  
  // جلب الكمية الحالية من السلة
  int qty = _cart[cartKey]?['qty'] ?? 0;

  return Stack(
    alignment: Alignment.center,
    children: [
      Column(
        children: [
          // الصورة
          Container(
            height: 250,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
              image: DecorationImage(
                image: NetworkImage(p['images'].isNotEmpty ? p['images'].first : 'https://via.placeholder.com/400'), 
                fit: BoxFit.cover
              ),
            ),
          ),
          
          // الاسم والوصف
          Text(p['name_ar'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Text(p['description_ar'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ),
          
          const SizedBox(height: 15),
          
          // اختيار الحجم (Scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: p['variants'].map<Widget>((v) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  avatar: currentVariantKey == v['key'] ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  label: Text('${v['name_ar']} (${v['price']} ج)'),
                  selected: currentVariantKey == v['key'],
                  onSelected: (s) => setState(() => _selectedVariant[p['id'].toString()] = v['key']),
                  selectedColor: const Color(0xFFFF5722),
                  labelStyle: TextStyle(color: currentVariantKey == v['key'] ? Colors.white : Colors.black),
                ),
              )).toList(),
            ),
          ),
          
          const SizedBox(height: 25),

          // التحكم في الكمية بتصميم شيك
          if (currentVariantKey.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                border: Border.all(color: Colors.grey.shade200)
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, 
                      color: qty > 0 ? Colors.redAccent : Colors.grey, 
                      size: 28
                    ),
                    onPressed: qty > 0 ? () => setState(() {
                      if (qty == 1) _cart.remove(cartKey); else _cart[cartKey]['qty']--;
                    }) : null,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 40),
                    alignment: Alignment.center,
                    child: Text('$qty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFFFF5722), size: 30),
                    onPressed: () {
                      final variant = p['variants'].firstWhere((v) => v['key'] == currentVariantKey);
                      setState(() {
                        if (qty == 0) {
                          _cart[cartKey] = {'p': p, 'v': variant, 'qty': 1};
                        } else {
                          _cart[cartKey]['qty']++;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            
          // مساحة أمان إضافية عشان البار السفلي ما يغطيش على الأزرار
          const SizedBox(height: 120),
        ],
      ),

      // أسهم التنقل الجانبية (Slider Arrows)
      if (_prodIdx > 0)
        Positioned(
          left: 5,
          top: 110,
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.8),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black),
              onPressed: () => setState(() => _prodIdx--),
            ),
          ),
        ),
      if (_prodIdx < prods.length - 1)
        Positioned(
          right: 5,
          top: 110,
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.8),
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black),
              onPressed: () => setState(() => _prodIdx++),
            ),
          ),
        ),
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
                "تأكيد الطلب 🧾", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 15),
              // عرض محتويات السلة قبل الإرسال
              ..._cart.values.map((it) => ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text("${it['p']['name_ar']} - ${it['v']['name_ar']}"),
                trailing: Text("x${it['qty']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
              const Divider(height: 30),
              TextField(
                controller: nameC, 
                decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder())
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneC, 
                decoration: const InputDecoration(labelText: 'رقم الموبايل', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addrC, 
                decoration: const InputDecoration(labelText: 'عنوان التوصيل بالتفصيل', border: OutlineInputBorder()),
                maxLines: 2
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),// ابحث عن الجزء ده داخل ElevatedButton في دالة _openCheckout واستبدله
onPressed: () async {
  if (nameC.text.isEmpty || phoneC.text.isEmpty || addrC.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ كمل البيانات يا ريس")));
    return;
  }

  try {
    String summary = _cart.values.map((it) => "${it['p']['name_ar']} (${it['v']['name_ar']}) x${it['qty']}").join(' , ');

    await Supabase.instance.client.from('orders').insert({
      'customer_snapshot': {
        'name': nameC.text, 
        'phone': phoneC.text, 
        'address': addrC.text,
        'items_summary': summary
      },
      'total': _cartTotal,
      'subtotal': _cartTotal, // أضفنا ده عشان نحل أيرور الصورة الأخيرة
      'status': 'pending'
    });

    if (mounted) {
      setState(() => _cart.clear());
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("🚀 طلبك وصل بنجاح!")));
    }
  } catch (e) {
    // لو لسه فيه أيرور هيظهرلك هنا بالتفصيل
    debugPrint("Final Error: $e");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ فشل الإرسال: $e")));
  }
},
                child: const Text("إرسال الطلب الآن 🚀", style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications() {
  // مش محتاجين async ولا محتاجين نجيب التليفون يدوي هنا
  // لأن البيانات موجودة فعلياً في قائمة _myOrders
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20))
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const Text("حالة طلباتك 📋", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: _myOrders.isEmpty 
              ? const Center(child: Text("لا توجد طلبات حالياً"))
              : ListView.builder(
                  itemCount: _myOrders.length,
                  itemBuilder: (context, index) {
                    final order = _myOrders[index];
                    // عرض الحالة بناءً على اللي جاي من سوبابيز
                    return ListTile(
                      leading: Icon(
                        order['status'] == 'pending' ? Icons.timer : Icons.check_circle,
                        color: order['status'] == 'pending' ? Colors.orange : Colors.green,
                      ),
                      title: Text("طلب بمبلغ: ${order['total']} ج"),
                      subtitle: Text("الحالة الحالية: ${order['status']}"),
                      trailing: Text(
                        order['created_at'].toString().substring(11, 16),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    ),
  );
}
}
