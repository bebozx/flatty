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

SupabaseClient get supa => Supabase.instance.client;

class CategoryModel {
  final String id, nameAr;
  CategoryModel({required this.id, required this.nameAr});
  static CategoryModel fromMap(Map<String, dynamic> m) => CategoryModel(id: m['id'].toString(), nameAr: m['name_ar'] ?? '');
}

class ProductModel {
  final String id, categoryId, nameAr, descriptionAr;
  List<String> images = [];
  List<Map<String, dynamic>> variants = [];
  ProductModel({required this.id, required this.categoryId, required this.nameAr, this.descriptionAr = ''});
}

class PizzacoClientApp extends StatelessWidget {
  const PizzacoClientApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF5722), primary: const Color(0xFFFF5722), secondary: const Color(0密1A237E).withOpacity(0)), // تم إصلاح اللون هنا
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
  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  String _selectedCatId = '';
  int _prodIdx = 0;
  final Map<String, dynamic> _cart = {};
  final Map<String, String> _selectedVariant = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final cats = await supa.from('categories').select().eq('is_active', true).order('order');
      _categories = (cats as List).map((e) => CategoryModel.fromMap(e)).toList();
      if (_categories.isNotEmpty) _selectedCatId = _categories.first.id;

      final prods = await supa.from('products').select().eq('is_active', true).order('order');
      final imgs = await supa.from('product_images').select();
      final vars = await supa.from('product_variants').select().eq('is_active', true);

      _products = (prods as List).map((p) {
        var m = ProductModel(id: p['id'].toString(), categoryId: p['category_id'].toString(), nameAr: p['name_ar'], descriptionAr: p['description_ar'] ?? '');
        m.images = (imgs as List).where((i) => i['product_id'] == m.id).map((i) => i['image_url'].toString()).toList();
        m.variants = (vars as List).where((v) => v['product_id'] == m.id).toList();
        if (m.variants.isNotEmpty) _selectedVariant[m.id] = m.variants.first['key'];
        return m;
      }).toList();
      setState(() => _loading = false);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _modernLoading();
    final filtered = _products.where((p) => p.categoryId == _selectedCatId).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('بيتزاكو 🍕', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.history, color: Colors.blue), onPressed: _showOrders),
          IconButton(icon: const Icon(Icons.phone, color: Colors.green), onPressed: () => launchUrl(Uri.parse('tel:0123456789'))),
        ],
      ),
      body: Column(
        children: [
          _buildCatList(),
          Expanded(child: filtered.isEmpty ? const Center(child: Text("لا يوجد منتجات")) : _buildSlider(filtered)),
          if (_cart.isNotEmpty) _buildCartBar(),
        ],
      ),
    );
  }

  Widget _modernLoading() => const Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Color(0xFFFF5722)), SizedBox(height: 20), Text("بنسخّن الفرن... 🍕")])));

  Widget _buildCatList() => SizedBox(
    height: 60,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _categories.length,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: ChoiceChip(
          label: Text(_categories[i].nameAr),
          selected: _selectedCatId == _categories[i].id,
          onSelected: (s) => setState(() { _selectedCatId = _categories[i].id; _prodIdx = 0; }),
          selectedColor: const Color(0xFFFF5722),
          labelStyle: TextStyle(color: _selectedCatId == _categories[i].id ? Colors.white : Colors.black),
        ),
      ),
    ),
  );

  Widget _buildSlider(List<ProductModel> prods) {
    final p = prods[_prodIdx];
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), image: DecorationImage(image: NetworkImage(p.images.isNotEmpty ? p.images.first : 'https://via.placeholder.com/400'), fit: BoxFit.cover)),
                ),
              ),
              const SizedBox(height: 15),
              Text(p.nameAr, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              Text(p.descriptionAr, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, children: p.variants.map((v) => ChoiceChip(label: Text('${v['name_ar']} (${v['price']} ج)'), selected: _selectedVariant[p.id] == v['key'], onSelected: (s) => setState(() => _selectedVariant[p.id] = v['key']))).toList()),
              const SizedBox(height: 15),
              ElevatedButton.icon(onPressed: () => _add(p), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5722), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)), icon: const Icon(Icons.add_shopping_cart), label: const Text("إضافة للسلة")),
            ],
          ),
        ),
        if (_prodIdx > 0) Positioned(left: 10, top: 180, child: _navBtn(Icons.arrow_back_ios, () => setState(() => _prodIdx--))),
        if (_prodIdx < prods.length - 1) Positioned(right: 10, top: 180, child: _navBtn(Icons.arrow_forward_ios, () => setState(() => _prodIdx++))),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback t) => CircleAvatar(backgroundColor: Colors.white.withOpacity(0.8), child: IconButton(icon: Icon(icon, size: 20, color: Colors.black), onPressed: t));

  void _add(ProductModel p) {
    final v = p.variants.firstWhere((v) => v['key'] == _selectedVariant[p.id]);
    setState(() => _cart["${p.id}-${v['key']}"] = {'p': p, 'v': v, 'qty': (_cart["${p.id}-${v['key']}"]?['qty'] ?? 0) + 1});
  }

  Widget _buildCartBar() => Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('السلة جاهزة ✨', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), ElevatedButton(onPressed: _checkout, child: const Text("اتمام الطلب"))]));

  Future<void> _checkout() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneC = TextEditingController(text: prefs.getString('cust_phone'));
    final nameC = TextEditingController(text: prefs.getString('cust_name'));
    final addrC = TextEditingController(text: prefs.getString('cust_address'));

    showModalBottomSheet(context: context, isScrollControlled: true, builder: (c) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: nameC, decoration: const InputDecoration(labelText: 'الاسم')),
      TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'الموبايل')),
      TextField(controller: addrC, decoration: const InputDecoration(labelText: 'العنوان بالتفصيل')),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: () async {
        final order = await supa.from('orders').insert({'customer_snapshot': {'name': nameC.text, 'phone': phoneC.text, 'address': addrC.text}, 'status': 'جديد', 'total': 0}).select().single();
        await prefs.setString('cust_phone', phoneC.text);
        await prefs.setString('cust_name', nameC.text);
        await prefs.setString('cust_address', addrC.text);
        setState(() => _cart.clear());
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم استلام طلبك يا بطل!")));
      }, child: const Text("تأكيد الطلب")),
      const SizedBox(height: 20),
    ])));
  }

  void _showOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('cust_phone');
    if (phone == null) return;
    showModalBottomSheet(context: context, builder: (c) => StreamBuilder(stream: supa.from('orders').stream(primaryKey: ['id']), builder: (ctx, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final my = snap.data!.where((o) => o['customer_snapshot']['phone'] == phone).toList();
      return ListView.builder(itemCount: my.length, itemBuilder: (ctx, i) => ListTile(title: Text('طلب #${my[i]['id'].toString().substring(0,6)}'), subtitle: Text('الحالة: ${my[i]['status']}'), trailing: const Icon(Icons.fastfood, color: Colors.orange)));
    }));
  }
}
