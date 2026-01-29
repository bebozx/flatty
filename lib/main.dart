import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// =====================
/// Supabase Config
/// =====================
const String SUPABASE_URL = 'https://fdmcuadexssqawrmhoqw.supabase.co';
const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkbWN1YWRleHNzcWF3cm1ob3F3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MTMwMjUsImV4cCI6MjA4NTE4OTAyNX0.jMgXBusEhmqPK_ogGzCvgBT4YfLiCEc9RH1hRxjzOqQ';

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
  final int order;
  final bool isActive;
  final String? imageUrl;
  CategoryModel({required this.id, required this.nameAr, required this.order, required this.isActive, this.imageUrl});

  static CategoryModel fromMap(Map<String, dynamic> m) => CategoryModel(
        id: m['id'].toString(),
        nameAr: (m['name_ar'] ?? '').toString(),
        order: int.tryParse('${m['order']}') ?? 0,
        isActive: m['is_active'] == true,
        imageUrl: m['image_url']?.toString(),
      );
}

class ProductModel {
  final String id, categoryId, nameAr;
  final String? descriptionAr;
  final int order;
  final bool isActive;
  List<ProductImage> images = [];
  List<ProductVariant> variants = [];

  ProductModel({required this.id, required this.categoryId, required this.nameAr, required this.order, required this.isActive, this.descriptionAr});

  static ProductModel fromMap(Map<String, dynamic> m) => ProductModel(
        id: m['id'].toString(),
        categoryId: m['category_id'].toString(),
        nameAr: (m['name_ar'] ?? '').toString(),
        descriptionAr: m['description_ar']?.toString(),
        order: int.tryParse('${m['order']}') ?? 0,
        isActive: m['is_active'] == true,
      );
}

class ProductImage {
  final String id, productId, imageUrl;
  final int order;
  ProductImage({required this.id, required this.productId, required this.imageUrl, required this.order});
  static ProductImage fromMap(Map<String, dynamic> m) => ProductImage(
    id: m['id'].toString(), productId: m['product_id'].toString(), 
    imageUrl: m['image_url']?.toString() ?? '', order: int.tryParse('${m['order']}') ?? 0);
}

class ProductVariant {
  final String id, productId, key, nameAr;
  final double price;
  final bool isActive;
  final int order;
  ProductVariant({required this.id, required this.productId, required this.key, required this.nameAr, required this.price, required this.isActive, required this.order});

  static ProductVariant fromMap(Map<String, dynamic> m) => ProductVariant(
        id: m['id'].toString(),
        productId: m['product_id'].toString(),
        key: (m['key'] ?? '').toString(),
        nameAr: (m['name_ar'] ?? '').toString(),
        price: double.tryParse('${m['price']}') ?? 0.0,
        isActive: m['is_active'] == true,
        order: int.tryParse('${m['order']}') ?? 0,
      );
}

class CartItemKey {
  final String productId, variantKey;
  const CartItemKey(this.productId, this.variantKey);
  @override
  bool operator ==(Object other) => identical(this, other) || other is CartItemKey && productId == other.productId && variantKey == other.variantKey;
  @override
  int get hashCode => productId.hashCode ^ variantKey.hashCode;
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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepOrange),
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
  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  final Map<String, List<ProductImage>> _imagesByProduct = {};
  final Map<String, List<ProductVariant>> _variantsByProduct = {};
  final Map<String, String> _selectedVariantKey = {};
  final Map<CartItemKey, CartItem> _cart = {};
  double _deliveryFee = 0.0;
  String _currency = 'EGP';
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  Future<void> _bootstrap() async {
    setState(() { _loading = true; _error = null; });
    try {
      final settings = await supa.from('app_settings').select().eq('id', 'general').maybeSingle();
      if (settings != null) {
        _currency = settings['currency'] ?? 'EGP';
        _deliveryFee = double.tryParse('${settings['delivery_fee']}') ?? 0.0;
      }

      final catsRaw = await supa.from('categories').select().eq('is_active', true).order('order');
      _categories = (catsRaw as List).map((e) => CategoryModel.fromMap(e)).toList();

      final prodsRaw = await supa.from('products').select().eq('is_active', true).order('order');
      _products = (prodsRaw as List).map((e) => ProductModel.fromMap(e)).toList();

      final imgsRaw = await supa.from('product_images').select().order('order');
      _imagesByProduct.clear();
      for (var im in (imgsRaw as List).map((e) => ProductImage.fromMap(e))) {
        (_imagesByProduct[im.productId] ??= []).add(im);
      }

      final varsRaw = await supa.from('product_variants').select().eq('is_active', true).order('order');
      _variantsByProduct.clear();
      for (var v in (varsRaw as List).map((e) => ProductVariant.fromMap(e))) {
        (_variantsByProduct[v.productId] ??= []).add(v);
      }

      for (var p in _products) {
        p.images = _imagesByProduct[p.id] ?? [];
        p.variants = _variantsByProduct[p.id] ?? [];
        if (p.variants.isNotEmpty) _selectedVariantKey[p.id] = p.variants.first.key;
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String money(double v) => '${v.toStringAsFixed(0)} $_currency';
  double get _cartSubtotal => _cart.values.fold(0, (p, e) => p + e.lineTotal);
  double get _cartTotal => _cartSubtotal + (_cart.isNotEmpty ? _deliveryFee : 0);
  String normalizePhone(String ph) => ph.replaceAll(RegExp(r'\D'), '');

  void _addToCart(ProductModel p) {
    final vKey = _selectedVariantKey[p.id];
    final v = p.variants.firstWhere((x) => x.key == vKey, orElse: () => p.variants.first);
    final key = CartItemKey(p.id, v.key);
    setState(() {
      if (_cart.containsKey(key)) { _cart[key]!.qty++; } 
      else { _cart[key] = CartItem(productId: p.id, productNameAr: p.nameAr, variantKey: v.key, variantNameAr: v.nameAr, unitPrice: v.price, qty: 1); }
    });
  }

  /// =====================
  /// Checkout Modal
  /// =====================
  Future<void> _openCheckout() async {
    if (_cart.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final nameCtrl = TextEditingController(text: prefs.getString('cust_name') ?? '');
    final phoneCtrl = TextEditingController(text: prefs.getString('cust_phone') ?? '');
    final addrCtrl = TextEditingController(text: prefs.getString('cust_address') ?? '');

    await showModalBottomSheet(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) {
          bool sending = false;
          return Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('إتمام الطلب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: addrCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'العنوان بالتفصيل', border: OutlineInputBorder())),
                  const Divider(height: 32),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('المجموع:'), Text(money(_cartSubtotal))]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('التوصيل:'), Text(money(_deliveryFee))]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold)), Text(money(_cartTotal), style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: FilledButton(
                    onPressed: sending ? null : () async {
                      if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty || addrCtrl.text.isEmpty) return;
                      setLocal(() => sending = true);
                      try {
                        await prefs.setString('cust_name', nameCtrl.text);
                        await prefs.setString('cust_phone', phoneCtrl.text);
                        await prefs.setString('cust_address', addrCtrl.text);

                        final order = await supa.from('orders').insert({
                          'customer_snapshot': {'name': nameCtrl.text, 'phone': phoneCtrl.text, 'address': addrCtrl.text},
                          'subtotal': _cartSubtotal, 'delivery_fee': _deliveryFee, 'total': _cartTotal, 'status': 'pending',
                        }).select('id').single();

                        final items = _cart.values.map((it) => {
                          'order_id': order['id'], 'product_id': it.productId, 'product_name_ar': it.productNameAr,
                          'variant_key': it.variantKey, 'variant_name_ar': it.variantNameAr, 'unit_price': it.unitPrice, 'quantity': it.qty
                        }).toList();
                        
                        await supa.from('order_items').insert(items);
                        setState(() => _cart.clear());
                        if (mounted) Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إرسال طلبك بنجاح')));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                      } finally { setLocal(() => sending = false); }
                    },
                    child: sending ? const CircularProgressIndicator(color: Colors.white) : const Text('تأكيد الطلب الآن'),
                  ))
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بيتزاكو 🍕'), centerTitle: true),
      body: _loading 
        ? const Center(child: CircularProgressIndicator()) 
        : _error != null 
          ? Center(child: Column(children: [Text('خطأ: $_error'), ElevatedButton(onPressed: _bootstrap, child: const Text('اعادة'))])) 
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(controller: _searchCtrl, decoration: const InputDecoration(hintText: 'ابحث...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder())),
                ),
                Expanded(
                  child: ListView(
                    children: _categories.map((cat) {
                      final items = _products.where((p) => p.categoryId == cat.id && p.nameAr.toLowerCase().contains(_query)).toList();
                      if (items.isEmpty) return const SizedBox();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(padding: const EdgeInsets.all(12), child: Text(cat.nameAr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange))),
                          ...items.map((p) => Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: p.images.isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p.images.first.imageUrl, width: 60, height: 60, fit: BoxFit.cover)) : const Icon(Icons.pizza, size: 40),
                                    title: Text(p.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(p.descriptionAr ?? ''),
                                  ),
                                  Wrap(spacing: 8, children: p.variants.map((v) => ChoiceChip(
                                    label: Text('${v.nameAr} (${money(v.price)})'),
                                    selected: _selectedVariantKey[p.id] == v.key,
                                    onSelected: (s) => setState(() => _selectedVariantKey[p.id] = v.key),
                                  )).toList()),
                                  Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => _addToCart(p), icon: const Icon(Icons.add_shopping_cart), label: const Text('إضافة للسلة'))),
                                ],
                              ),
                            ),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                if (_cart.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text('${_cart.length} منتجات', style: const TextStyle(fontSize: 12)),
                          Text(money(_cartTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        ]),
                        FilledButton(onPressed: _openCheckout, child: const Text('عرض السلة')),
                      ],
                    ),
                  )
              ],
            ),
    );
  }
}
