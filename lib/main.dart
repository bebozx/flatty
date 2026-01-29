import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String SUPABASE_URL = 'https://fdmcuadexssqawrmhoqw.supabase.co';
const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkbWN1YWRleHNzcWF3rmhoqwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MTMwMjUsImV4cCI6MjA4NTE4OTAyNX0.jMgXBusEhmqPK_ogGzCvgBT4YfLiCEc9RH1hRxjzOqQ';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);
  runApp(const PizzacoClientApp());
}

SupabaseClient get supa => Supabase.instance.client;

/// =====================
/// Models
/// =====================
class CategoryModel {
  final String id, nameAr;
  CategoryModel({required this.id, required this.nameAr});
  static CategoryModel fromMap(Map<String, dynamic> m) => CategoryModel(id: m['id'].toString(), nameAr: m['name_ar'] ?? '');
}

class ProductModel {
  final String id, categoryId, nameAr;
  final String? descriptionAr;
  List<String> imageUrls = [];
  List<ProductVariant> variants = [];
  ProductModel({required this.id, required this.categoryId, required this.nameAr, this.descriptionAr});
  static ProductModel fromMap(Map<String, dynamic> m) => ProductModel(id: m['id'].toString(), categoryId: m['category_id'].toString(), nameAr: m['name_ar'] ?? '', descriptionAr: m['description_ar']);
}

class ProductVariant {
  final String key, nameAr;
  final double price;
  ProductVariant({required this.key, required this.nameAr, required this.price});
  static ProductVariant fromMap(Map<String, dynamic> m) => ProductVariant(key: m['key'] ?? '', nameAr: m['name_ar'] ?? '', price: double.tryParse('${m['price']}') ?? 0.0);
}

class CartItem {
  final String productId, productNameAr, variantKey, variantNameAr;
  final double unitPrice;
  int qty;
  CartItem({required this.productId, required this.productNameAr, required this.variantKey, required this.variantNameAr, required this.unitPrice, required this.qty});
  double get lineTotal => unitPrice * qty;
}

/// =====================
/// Main UI
/// =====================
class PizzacoClientApp extends StatelessWidget {
  const PizzacoClientApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بيتزاكو',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepOrange, fontFamily: 'Cairo'),
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
  int _productIdx = 0;
  final Map<String, String> _selectedVariantKey = {};
  final Map<String, CartItem> _cart = {};
  double _deliveryFee = 0.0;
  String _currency = 'EGP';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final settings = await supa.from('app_settings').select().eq('id', 'general').maybeSingle();
      if (settings != null) {
        _currency = settings['currency'] ?? 'EGP';
        _deliveryFee = double.tryParse('${settings['delivery_fee']}') ?? 0.0;
      }
      final cats = await supa.from('categories').select().eq('is_active', true).order('order');
      _categories = (cats as List).map((e) => CategoryModel.fromMap(e)).toList();
      if (_categories.isNotEmpty) _selectedCatId = _categories.first.id;

      final prods = await supa.from('products').select().eq('is_active', true).order('order');
      _products = (prods as List).map((e) => ProductModel.fromMap(e)).toList();

      final imgs = await supa.from('product_images').select();
      final vars = await supa.from('product_variants').select().eq('is_active', true).order('order');

      for (var p in _products) {
        p.imageUrls = (imgs as List).where((i) => i['product_id'] == p.id).map((i) => i['image_url'].toString()).toList();
        p.variants = (vars as List).where((v) => v['product_id'] == p.id).map((v) => ProductVariant.fromMap(v)).toList();
        if (p.variants.isNotEmpty) _selectedVariantKey[p.id] = p.variants.first.key;
      }
      setState(() => _loading = false);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _callRestaurant() async {
    final url = Uri.parse('tel:0123456789'); 
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _showMyOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('cust_phone');
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => phone == null 
        ? const Center(child: Text('لم تقم بأي طلبات بعد'))
        : StreamBuilder(
            stream: supa.from('orders').stream(primaryKey: ['id']).order('created_at'),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final myOrders = snapshot.data!.where((o) => o['customer_snapshot']['phone'] == phone).toList();
              return ListView.builder(
                itemCount: myOrders.length,
                itemBuilder: (c, i) => ListTile(
                  leading: const Icon(Icons.shopping_bag, color: Colors.deepOrange),
                  title: Text('طلب #${myOrders[i]['id'].toString().substring(0,6)}'),
                  subtitle: Text('الحالة: ${myOrders[i]['status']}'),
                  trailing: Text('${myOrders[i]['total']} $_currency', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final filtered = _products.where((p) => p.categoryId == _selectedCatId).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('بيتزاكو 🍕', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: _showMyOrders, icon: const Icon(Icons.history, color: Colors.blue)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_active_outlined, color: Colors.amber)),
                  IconButton(onPressed: _callRestaurant, icon: const Icon(Icons.phone, color: Colors.green)),
                ],
              ),
            ),
            // Categories
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: _categories.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    label: Text(c.nameAr),
                    onPressed: () => setState(() { _selectedCatId = c.id; _productIdx = 0; }),
                    backgroundColor: _selectedCatId == c.id ? Colors.deepOrange[100] : null,
                  ),
                )).toList(),
              ),
            ),
            // Slider
            Expanded(
              child: filtered.isEmpty ? const Center(child: Text('لا يوجد منتجات')) : Stack(
                children: [
                  _buildProductView(filtered[_productIdx]),
                  if (_productIdx > 0) Positioned(left: 10, top: 150, child: _nav(Icons.arrow_back_ios, () => setState(() => _productIdx--))),
                  if (_productIdx < filtered.length - 1) Positioned(right: 10, top: 150, child: _nav(Icons.arrow_forward_ios, () => setState(() => _productIdx++))),
                ],
              ),
            ),
            if (_cart.isNotEmpty) _buildCartBottom(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductView(ProductModel p) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              image: DecorationImage(image: NetworkImage(p.imageUrls.isNotEmpty ? p.imageUrls.first : 'https://via.placeholder.com/400'), fit: BoxFit.cover),
            ),
          ),
        ),
        Text(p.nameAr, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        Text(p.descriptionAr ?? '', style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: p.variants.map((v) => ChoiceChip(
            label: Text('${v.nameAr} - ${v.price.toStringAsFixed(0)}'),
            selected: _selectedVariantKey[p.id] == v.key,
            onSelected: (_) => setState(() => _selectedVariantKey[p.id] = v.key),
          )).toList(),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: () => _addToCart(p),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            child: const Text('أضف للسلة'),
          ),
        ),
      ],
    );
  }

  Widget _nav(IconData i, VoidCallback t) => CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: Icon(i, size: 18, color: Colors.black), onPressed: t));

  void _addToCart(ProductModel p) {
    final vKey = _selectedVariantKey[p.id]!;
    final v = p.variants.firstWhere((v) => v.key == vKey);
    setState(() => _cart["${p.id}-$vKey"] = CartItem(productId: p.id, productNameAr: p.nameAr, variantKey: v.key, variantNameAr: v.nameAr, unitPrice: v.price, qty: (_cart["${p.id}-$vKey"]?.qty ?? 0) + 1));
  }

  Widget _buildCartBottom() {
    final total = _cart.values.fold(0.0, (s, e) => s + e.lineTotal) + _deliveryFee;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('الإجمالي: ${total.toStringAsFixed(0)} $_currency', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ElevatedButton(onPressed: _checkout, child: const Text('طلب الآن')),
        ],
      ),
    );
  }

  Future<void> _checkout() async {
    final prefs = await SharedPreferences.getInstance();
    final nameC = TextEditingController(text: prefs.getString('cust_name'));
    final phoneC = TextEditingController(text: prefs.getString('cust_phone'));
    final addrC = TextEditingController(text: prefs.getString('cust_address'));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'الموبايل')),
            TextField(controller: addrC, decoration: const InputDecoration(labelText: 'العنوان')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final order = await supa.from('orders').insert({
                  'customer_snapshot': {'name': nameC.text, 'phone': phoneC.text, 'address': addrC.text},
                  'total': _cart.values.fold(0.0, (s, e) => s + e.lineTotal) + _deliveryFee,
                  'status': 'قيد الانتظار'
                }).select().single();
                
                await supa.from('order_items').insert(_cart.values.map((e) => {
                  'order_id': order['id'], 'product_name_ar': e.productNameAr, 'quantity': e.qty, 'unit_price': e.unitPrice
                }).toList());

                await prefs.setString('cust_name', nameC.text);
                await prefs.setString('cust_phone', phoneC.text);
                await prefs.setString('cust_address', addrC.text);

                setState(() => _cart.clear());
                Navigator.pop(context);
              },
              child: const Text('تأكيد'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
