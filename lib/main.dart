// lib/main.dart
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// =====================
/// إعدادات Supabase
/// =====================
const String SUPABASE_URL = 'https://fdmcuadexssqawrmhoqw.supabase.co';
const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkbWN1YWRleHNzcWF3cm1ob3F3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MTMwMjUsImV4cCI6MjA4NTE4OTAyNX0.jMgXBusEhmqPK_ogGzCvgBT4YfLiCEc9RH1hRxjzOqQ';
const String STORAGE_BUCKET = 'pizzaco';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
  );
  runApp(const AdminApp());
}

SupabaseClient get supa => Supabase.instance.client;

/// =====================
/// تطبيق الأدمن
/// =====================
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بيتزاكو - الأدمن',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
        fontFamily: 'Arial',
      ),
      home: const AdminSignInPage(),
    );
  }
}

/// =====================
/// صفحة تسجيل الدخول
/// =====================
class AdminSignInPage extends StatefulWidget {
  const AdminSignInPage({super.key});

  @override
  State<AdminSignInPage> createState() => _AdminSignInPageState();
}

class _AdminSignInPageState extends State<AdminSignInPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // تسجيل دخول عبر Supabase Auth
      final authResp = await supa.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final user = authResp.user;
      if (user == null) {
        throw 'فشل تسجيل الدخول، تأكد من البريد/كلمة المرور';
      }

      // تحقق إن الـ UID موجود في جدول admins و active=true
      final adminResp = await supa
          .from('admins')
          .select('uid,name,role,active')
          .eq('uid', user.id)
          .eq('active', true)
          .maybeSingle();

      if (adminResp == null) {
        throw 'الحساب ليس لديه صلاحيات الأدمن أو غير مُفعّل.';
      }

      // نجاح → افتح لوحة التحكم
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل دخول الأدمن')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ادخل بريدك وكلمة المرور الخاصة بالأدمن'),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(_error!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 12)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _signIn,
                    icon: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('دخول'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// =====================
/// لوحة تحكم الأدمن
/// =====================
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = supa.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('بيتزاكو - لوحة الأدمن'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.category), text: 'الفئات'),
            Tab(icon: Icon(Icons.local_pizza), text: 'المنتجات'),
            Tab(icon: Icon(Icons.tune), text: 'الأحجام والصور'),
            Tab(icon: Icon(Icons.receipt_long), text: 'الطلبات'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(userEmail)),
          ),
          IconButton(
            onPressed: () async {
              await supa.auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AdminSignInPage()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          CategoriesTab(),
          ProductsTab(),
          VariantsAndImagesTab(),
          OrdersTab(),
        ],
      ),
    );
  }
}

/// =====================
/// تبويب الفئات (Categories)
/// =====================
class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  Future<List<dynamic>> _fetchCategories() async {
    final res = await supa
        .from('categories')
        .select('id,name_ar,name_en,order,is_active,image_url')
        .order('order', ascending: true);
    return res;
  }

  Future<void> _createOrEditCategory({Map<String, dynamic>? existing}) async {
  final nameArCtrl = TextEditingController(text: existing?['name_ar'] ?? '');
  final nameEnCtrl = TextEditingController(text: existing?['name_en'] ?? '');
  final orderCtrl =
      TextEditingController(text: existing?['order']?.toString() ?? '0');

  bool isActive = existing?['is_active'] ?? true;
  String? imageUrl = existing?['image_url'];

  // ✅ لو بنضيف جديد ورفعنا صورة قبل الحفظ: نخزن الـ id هنا
  String? draftCategoryId = existing?['id'];
  String? pickedName;

  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setLocalState) {
        return AlertDialog(
          title: Text(existing == null ? 'إضافة فئة' : 'تعديل فئة'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameArCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم بالعربية'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameEnCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية (اختياري)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الترتيب'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isActive,
                  onChanged: (v) => setLocalState(() => isActive = v),
                  title: const Text('مفعّلة'),
                ),
                const Divider(),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pickedName != null
                            ? 'تم اختيار: $pickedName'
                            : (imageUrl == null ? 'لا توجد صورة غلاف' : 'صورة موجودة'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                          if (picked == null) return;

                          final bytes = await picked.readAsBytes();
                          pickedName = picked.name;

                          // ✅ لو لسه مفيش id (إضافة جديدة) اعمل insert مرة واحدة فقط
                          if (draftCategoryId == null) {
                            final inserted = await supa.from('categories').insert({
                              'name_ar': nameArCtrl.text.trim().isEmpty
                                  ? 'فئة مؤقتة'
                                  : nameArCtrl.text.trim(),
                              'name_en': nameEnCtrl.text.trim().isEmpty ? null : nameEnCtrl.text.trim(),
                              'order': int.tryParse(orderCtrl.text) ?? 0,
                              'is_active': isActive,
                            }).select('id').single();

                            draftCategoryId = inserted['id'] as String;
                          }

                          final id = draftCategoryId!;
                          final ext = p.extension(picked.name).toLowerCase();
                          final safeExt = ext.isEmpty ? '.jpg' : ext;
                          final filename = 'cover$safeExt';
                          final storagePath = 'categories/$id/$filename';

                          await supa.storage.from(STORAGE_BUCKET).uploadBinary(
                                storagePath,
                                bytes,
                                fileOptions: FileOptions(
                                  upsert: true,
                                  contentType:
                                      'image/${safeExt.replaceAll('.', '').isEmpty ? 'jpeg' : safeExt.replaceAll('.', '')}',
                                ),
                              );

                          final pubUrl = supa.storage.from(STORAGE_BUCKET).getPublicUrl(storagePath);

                          await supa.from('categories').update({'image_url': pubUrl}).eq('id', id);

                          setLocalState(() => imageUrl = pubUrl);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم رفع صورة الغلاف بنجاح')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل رفع الصورة: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.upload),
                      label: const Text('رفع غلاف'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // ✅ لو عملنا draft insert (رفع صورة) وبعدين المستخدم لغى: نمسح الصف المؤقت
                // (اختياري لكنه بيمنع بواقي في الجدول)
                if (existing == null && draftCategoryId != null) {
                  try {
                    await supa.from('categories').delete().eq('id', draftCategoryId!);
                  } catch (_) {}
                }
                if (mounted) Navigator.pop(context);
              },
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final payload = {
                  'name_ar': nameArCtrl.text.trim(),
                  'name_en': nameEnCtrl.text.trim().isEmpty ? null : nameEnCtrl.text.trim(),
                  'order': int.tryParse(orderCtrl.text) ?? 0,
                  'is_active': isActive,
                  'image_url': imageUrl,
                };

                // ✅ أهم سطر: لو عندنا draftCategoryId → UPDATE بدل INSERT
                if (draftCategoryId == null) {
                  await supa.from('categories').insert(payload);
                } else {
                  await supa.from('categories').update(payload).eq('id', draftCategoryId!);
                }

                if (mounted) Navigator.pop(context);
                setState(() {}); // refresh الليست
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    ),
  );
}
  
  Future<void> _deleteCategory(String id) async {
    await supa.from('categories').delete().eq('id', id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchCategories(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final cats = snap.data!;
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _createOrEditCategory(),
            icon: const Icon(Icons.add),
            label: const Text('إضافة فئة'),
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (_, i) {
              final c = cats[i];
              return Card(
                child: ListTile(
                  leading: c['image_url'] != null
                      ? CircleAvatar(
                          backgroundImage:
                              NetworkImage(c['image_url'] as String),
                        )
                      : const CircleAvatar(child: Icon(Icons.category)),
                  title: Text(c['name_ar'] ?? ''),
                  subtitle: Text(
                      'ترتيب: ${c['order']} | مفعّلة: ${c['is_active'] ? 'نعم' : 'لا'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          onPressed: () => _createOrEditCategory(existing: c),
                          icon: const Icon(Icons.edit)),
                      IconButton(
                        onPressed: () => _deleteCategory(c['id']),
                        icon: const Icon(Icons.delete, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: cats.length,
          ),
        );
      },
    );
  }
}

/// =====================
/// تبويب المنتجات (Products)
/// =====================
class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String? _selectedCategoryId;

  Future<List<dynamic>> _fetchCategories() async {
    final res = await supa
        .from('categories')
        .select('id,name_ar,order')
        .order('order', ascending: true);
    return res;
  }

  Future<List<dynamic>> _fetchProducts(String? categoryId) async {
    var q = supa
        .from('products')
        .select(
            'id,category_id,name_ar,name_en,description_ar,order,is_active');
    if (categoryId != null) {
      q = q.eq('category_id', categoryId);
    }
    final res = await q.order('order', ascending: true);
    return res;
  }

  Future<void> _createOrEditProduct(
      {Map<String, dynamic>? existing}) async {
    final cats = await _fetchCategories();
    String? catId = existing?['category_id'] ?? _selectedCategoryId;
    final nameArCtrl =
        TextEditingController(text: existing?['name_ar'] ?? '');
    final nameEnCtrl =
        TextEditingController(text: existing?['name_en'] ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description_ar'] ?? '');
    final orderCtrl = TextEditingController(
        text: existing?['order']?.toString() ?? '0');
    bool isActive = existing?['is_active'] ?? true;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'إضافة منتج' : 'تعديل منتج'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: catId,
                items: cats
                    .map((c) => DropdownMenuItem<String>(
                          value: c['id'] as String,
                          child: Text(c['name_ar'] as String),
                        ))
                    .toList(),
                onChanged: (v) => catId = v,
                decoration:
                    const InputDecoration(labelText: 'اختر الفئة'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameArCtrl,
                decoration:
                    const InputDecoration(labelText: 'اسم المنتج'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameEnCtrl,
                decoration: const InputDecoration(
                    labelText: 'اسم إنجليزي (اختياري)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration:
                    const InputDecoration(labelText: 'الوصف'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: orderCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'الترتيب'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: isActive,
                onChanged: (v) => setState(() => isActive = v),
                title: const Text('مفعّل'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (catId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('اختر فئة للمنتج أولًا')));
                return;
              }
              final payload = {
                'category_id': catId,
                'name_ar': nameArCtrl.text.trim(),
                'name_en': nameEnCtrl.text.trim().isEmpty
                    ? null
                    : nameEnCtrl.text.trim(),
                'description_ar': descCtrl.text.trim().isEmpty
                    ? null
                    : descCtrl.text.trim(),
                'order': int.tryParse(orderCtrl.text) ?? 0,
                'is_active': isActive,
              };
              if (existing == null) {
                await supa.from('products').insert(payload);
              } else {
                await supa
                    .from('products')
                    .update(payload)
                    .eq('id', existing['id']);
              }
              if (mounted) Navigator.pop(context);
              setState(() {});
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String id) async {
    await supa.from('products').delete().eq('id', id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchCategories(),
      builder: (_, catSnap) {
        if (!catSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final cats = catSnap.data!;
        _selectedCategoryId ??=
            cats.isNotEmpty ? cats.first['id'] as String : null;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('الفئة: '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedCategoryId,
                      isExpanded: true,
                      items: cats
                          .map((c) => DropdownMenuItem<String>(
                                value: c['id'] as String,
                                child: Text(c['name_ar'] as String),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCategoryId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _createOrEditProduct(),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة منتج'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _fetchProducts(_selectedCategoryId),
                builder: (_, prodSnap) {
                  if (!prodSnap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  final products = prodSnap.data!;
                  if (products.isEmpty) {
                    return const Center(child: Text('لا منتجات بعد'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (_, i) {
                      final p = products[i];
                      return Card(
                        child: ListTile(
                          title: Text(p['name_ar'] ?? ''),
                          subtitle: Text(
                              'ترتيب: ${p['order']} | مفعّل: ${p['is_active'] ? 'نعم' : 'لا'}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  onPressed: () =>
                                      _createOrEditProduct(existing: p),
                                  icon: const Icon(Icons.edit)),
                              IconButton(
                                  onPressed: () =>
                                      _deleteProduct(p['id']),
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red)),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemCount: products.length,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// =====================
/// تبويب الأحجام والصور
/// =====================
class VariantsAndImagesTab extends StatefulWidget {
  const VariantsAndImagesTab({super.key});

  @override
  State<VariantsAndImagesTab> createState() => _VariantsAndImagesTabState();
}

class _VariantsAndImagesTabState extends State<VariantsAndImagesTab> {
  String? _selectedProductId;

  Future<List<dynamic>> _fetchAllProducts() async {
    final res = await supa
        .from('products')
        .select('id,name_ar,order,is_active')
        .order('order', ascending: true);
    return res;
  }

  Future<List<dynamic>> _fetchVariants(String productId) async {
    final res = await supa
        .from('product_variants')
        .select('id,key,name_ar,price,is_active,order')
        .eq('product_id', productId)
        .order('order', ascending: true);
    return res;
  }

  Future<List<dynamic>> _fetchImages(String productId) async {
    final res = await supa
        .from('product_images')
        .select('id,image_url,order')
        .eq('product_id', productId)
        .order('order', ascending: true);
    return res;
  }

  Future<void> _addOrEditVariant(
      String productId, Map<String, dynamic>? existing) async {
    final keyCtrl = TextEditingController(text: existing?['key'] ?? '');
    final nameCtrl =
        TextEditingController(text: existing?['name_ar'] ?? '');
    final priceCtrl = TextEditingController(
        text: existing?['price']?.toString() ?? '');
    final orderCtrl = TextEditingController(
        text: existing?['order']?.toString() ?? '0');
    bool isActive = existing?['is_active'] ?? true;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'إضافة حجم' : 'تعديل حجم'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(
                    labelText: 'المفتاح (small/medium/large)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'الاسم الظاهر'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'السعر'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: orderCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'الترتيب'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: isActive,
                onChanged: (v) => setState(() => isActive = v),
                title: const Text('مفعّل'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final payload = {
                'product_id': productId,
                'key': keyCtrl.text.trim(),
                'name_ar': nameCtrl.text.trim(),
                'price': double.tryParse(priceCtrl.text) ?? 0,
                'order': int.tryParse(orderCtrl.text) ?? 0,
                'is_active': isActive
              };
              if (existing == null) {
                await supa.from('product_variants').insert(payload);
              } else {
                await supa
                    .from('product_variants')
                    .update(payload)
                    .eq('id', existing['id']);
              }
              if (mounted) Navigator.pop(context);
              setState(() {});
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVariant(String id) async {
    await supa.from('product_variants').delete().eq('id', id);
    setState(() {});
  }

 Future<void> _uploadImages(String productId) async {
  try {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      // خفيفة على الذاكرة: خليه false، ونستخدم path لو متاح
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;

    int indexStart = 0;
    final existing = await _fetchImages(productId);
    if (existing.isNotEmpty) {
      indexStart = (existing.last['order'] as int? ?? existing.length);
    }

    for (int i = 0; i < res.files.length; i++) {
      final f = res.files[i];

      final ext = p.extension(f.name).toLowerCase(); // .jpg .png ...
      final safeExt = ext.isEmpty ? '.jpg' : ext;
      final filename = 'img${indexStart + i + 1}$safeExt';
      final storagePath = 'products/$productId/$filename';

      // content-type بسيط
      String contentType = 'application/octet-stream';
      final e = safeExt.replaceAll('.', '');
      if (e == 'jpg' || e == 'jpeg') contentType = 'image/jpeg';
      else if (e == 'png') contentType = 'image/png';
      else if (e == 'webp') contentType = 'image/webp';
      else if (e == 'gif') contentType = 'image/gif';

      // ✅ أهم نقطة: متعملش ! على path
      String publicUrl;

      if (f.path != null && f.path!.isNotEmpty) {
        // ✅ الأفضل على الموبايل: رفع File مباشرة (بدون تحميله كله في الذاكرة)
        final file = io.File(f.path!);

        await supa.storage.from(STORAGE_BUCKET).upload(
              storagePath,
              file,
              fileOptions: FileOptions(
                upsert: true,
                contentType: contentType,
              ),
            );

        publicUrl = supa.storage.from(STORAGE_BUCKET).getPublicUrl(storagePath);
      } else if (f.bytes != null) {
        // ✅ لو path مش متاح (نادر على الموبايل) نستخدم bytes
        await supa.storage.from(STORAGE_BUCKET).uploadBinary(
              storagePath,
              f.bytes!,
              fileOptions: FileOptions(
                upsert: true,
                contentType: contentType,
              ),
            );

        publicUrl = supa.storage.from(STORAGE_BUCKET).getPublicUrl(storagePath);
      } else {
        // ✅ لا bytes ولا path → ما نكراش، نبلّغ المستخدم
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر قراءة الملف: ${f.name} (جرّب صورة من المعرض المحلي)')),
          );
        }
        continue;
      }

      // ✅ خزّن URL في جدول الصور
      await supa.from('product_images').insert({
        'product_id': productId,
        'image_url': publicUrl,
        'order': indexStart + i + 1,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع صور المنتج بنجاح')),
      );
      setState(() {});
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفع صور المنتج: $e')),
      );
    }
  }
}
  Future<void> _deleteImage(String id) async {
    await supa.from('product_images').delete().eq('id', id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchAllProducts(),
      builder: (_, prodSnap) {
        if (!prodSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = prodSnap.data!;
        _selectedProductId ??=
            products.isNotEmpty ? products.first['id'] as String : null;

        return Column(
          children: [
            // اختيار المنتج
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('المنتج: '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedProductId,
                      isExpanded: true,
                      items: products
                          .map((p) => DropdownMenuItem<String>(
                                value: p['id'] as String,
                                child: Text(p['name_ar'] as String),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedProductId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _selectedProductId == null
                        ? null
                        : () => _uploadImages(_selectedProductId!),
                    icon: const Icon(Icons.upload),
                    label: const Text('رفع صور المنتج'),
                  ),
                ],
              ),
            ),
            if (_selectedProductId == null)
              const Expanded(
                  child:
                      Center(child: Text('اختر منتجًا لإدارة أحجامه وصوره')))
            else
              Expanded(
                child: Row(
                  children: [
                    // الأحجام
                    Expanded(
                      child: Column(
                        children: [
                          const ListTile(
                            title: Text('الأحجام/الخيارات'),
                            trailing: SizedBox.shrink(),
                          ),
                          Expanded(
                            child: FutureBuilder<List<dynamic>>(
                              future:
                                  _fetchVariants(_selectedProductId!),
                              builder: (_, varSnap) {
                                if (!varSnap.hasData) {
                                  return const Center(
                                      child:
                                          CircularProgressIndicator());
                                }
                                final variants = varSnap.data!;
                                return ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemBuilder: (_, i) {
                                    final v = variants[i];
                                    return Card(
                                      child: ListTile(
                                        title: Text(
                                            '${v['name_ar']} (${v['key']})'),
                                        subtitle: Text(
                                            'سعر: ${v['price']} | ترتيب: ${v['order']} | مفعّل: ${v['is_active'] ? 'نعم' : 'لا'}'),
                                        trailing: Row(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              onPressed: () =>
                                                  _addOrEditVariant(
                                                      _selectedProductId!,
                                                      v),
                                              icon: const Icon(
                                                  Icons.edit),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _deleteVariant(
                                                      v['id']),
                                              icon: const Icon(Icons
                                                  .delete_outline),
                                              color: Colors.red,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemCount: variants.length,
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _addOrEditVariant(
                                    _selectedProductId!, null),
                                icon: const Icon(Icons.add),
                                label: const Text('إضافة حجم جديد'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // الصور
                    Expanded(
                      child: Column(
                        children: [
                          const ListTile(
                            title: Text('صور المنتج'),
                            trailing: SizedBox.shrink(),
                          ),
                          Expanded(
                            child: FutureBuilder<List<dynamic>>(
                              future: _fetchImages(_selectedProductId!),
                              builder: (_, imgSnap) {
                                if (!imgSnap.hasData) {
                                  return const Center(
                                      child:
                                          CircularProgressIndicator());
                                }
                                final imgs = imgSnap.data!;
                                if (imgs.isEmpty) {
                                  return const Center(
                                      child: Text(
                                          'لا صور بعد — ارفع صور المنتج'));
                                }
                                return GridView.builder(
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 1,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemBuilder: (_, i) {
                                    final im = imgs[i];
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          im['image_url'] as String,
                                          fit: BoxFit.cover,
                                        ),
                                        Positioned(
                                          right: 4,
                                          top: 4,
                                          child: Container(
                                            padding:
                                                const EdgeInsets.all(4),
                                            color: Colors.black54,
                                            child: Text(
                                              '#${im['order']}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 4,
                                          top: 4,
                                          child: IconButton.filled(
                                            style: const ButtonStyle(
                                              backgroundColor:
                                                  MaterialStatePropertyAll(
                                                      Colors.red),
                                            ),
                                            icon: const Icon(
                                                Icons.delete,
                                                size: 18),
                                            onPressed: () =>
                                                _deleteImage(im['id']),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                  itemCount: imgs.length,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// =====================
/// تبويب الطلبات (Orders)
/// =====================
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  String _status = 'pending';

  Future<List<dynamic>> _fetchOrders() async {
    final res = await supa
        .from('orders')
        .select(
            'id,status,total,subtotal,delivery_fee,discount,created_at,customer_snapshot,order_items(*)')
        .eq('status', _status)
        .order('created_at', ascending: false);
    return res;
  }

  Future<void> _updateOrderStatus(String id, String newStatus) async {
    await supa.from('orders').update({'status': newStatus}).eq('id', id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final statuses = const [
      'pending',
      'accepted',
      'preparing',
      'out_for_delivery',
      'delivered',
      'canceled'
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('الحالة: '),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _status,
                items: statuses
                    .map((s) => DropdownMenuItem<String>(
                          value: s,
                          child: Text(s),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? 'pending'),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث',
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _fetchOrders(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snap.data!;
              if (orders.isEmpty) {
                return const Center(child: Text('لا توجد طلبات بهذه الحالة'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemBuilder: (_, i) {
                  final o = orders[i];
                  final cust = o['customer_snapshot'] as Map<String, dynamic>?;
                  final items = (o['order_items'] as List<dynamic>? ?? [])
                      .cast<Map<String, dynamic>>();
                  return Card(
                    child: ExpansionTile(
                      title: Text(
                          'إجمالي: ${o['total']} جنيه | ${cust?['name'] ?? 'عميل'}'),
                      subtitle: Text(
                          'حالة: ${o['status']} | تاريخ: ${o['created_at']}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cust != null) ...[
                                Text('الاسم: ${cust['name']}'),
                                Text('الهاتف: ${cust['phone']}'),
                                Text('العنوان: ${cust['address']}'),
                                const SizedBox(height: 8),
                              ],
                              const Text('تفاصيل الطلب:'),
                              const SizedBox(height: 4),
                              ...items.map((it) => Text(
                                  '• ${it['product_name_ar']} (${it['variant_name_ar']}) × ${it['quantity']} = ${it['line_total']}')),
                              const Divider(),
                              Text(
                                  'المجموع: ${o['subtotal']} + توصيل: ${o['delivery_fee']} - خصم: ${o['discount']} = الإجمالي: ${o['total']}'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: () => _updateOrderStatus(
                                        o['id'], 'accepted'),
                                    child: const Text('قبول'),
                                  ),
                                  FilledButton(
                                    onPressed: () => _updateOrderStatus(
                                        o['id'], 'preparing'),
                                    child: const Text('جاري التحضير'),
                                  ),
                                  FilledButton(
                                    onPressed: () => _updateOrderStatus(
                                        o['id'], 'out_for_delivery'),
                                    child: const Text('خارج للتسليم'),
                                  ),
                                  FilledButton(
                                    onPressed: () => _updateOrderStatus(
                                        o['id'], 'delivered'),
                                    child: const Text('تم التسليم'),
                                  ),
                                  FilledButton(
                                    style: const ButtonStyle(
                                      backgroundColor:
                                          MaterialStatePropertyAll(
                                              Colors.red),
                                    ),
                                    onPressed: () => _updateOrderStatus(
                                        o['id'], 'canceled'),
                                    child: const Text('إلغاء'),
                                  ),
                                ],
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: orders.length,
              );
            },
          ),
        ),
      ],
    );
  }
}
