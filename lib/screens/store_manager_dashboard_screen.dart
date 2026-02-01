
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../models/store_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../providers/category_provider.dart';
import 'dart:typed_data'; // Added for Uint8List
import 'package:image_picker/image_picker.dart'; // Added for ImagePicker
import 'package:firebase_storage/firebase_storage.dart'; // Added for Storage

class StoreManagerDashboardScreen extends StatefulWidget {
  static const routeName = '/store-manager-dashboard';

  const StoreManagerDashboardScreen({super.key});

  @override
  State<StoreManagerDashboardScreen> createState() => _StoreManagerDashboardScreenState();
}

class _StoreManagerDashboardScreenState extends State<StoreManagerDashboardScreen> with SingleTickerProviderStateMixin {
  StoreModel? _store;
  bool _isLoadingStore = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchStoreDetails();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStoreDetails() async {
    final auth = context.read<AuthProvider>();
    // Refresh user data to ensure we have the latest storeId assignment
    await auth.refreshUser();
    final storeId = auth.currentUser?.storeId;

    if (storeId == null) {
      if (mounted) setState(() => _isLoadingStore = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('stores').doc(storeId).get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _store = StoreModel.fromFirestore(doc);
            _isLoadingStore = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingStore = false);
      }
    } catch (e) {
      debugPrint('Error fetching store: $e');
      if (mounted) setState(() => _isLoadingStore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStore) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_store == null) {
      final auth = context.read<AuthProvider>(); // Define auth here for use in the debug info
      return Scaffold(
        appBar: AppBar(title: const Text('Store Manager Dashboard')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.store, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                const Text(
                  'No Store Assigned',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your account has the "Store Manager" role, but no specific store is linked to your profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Debug Information:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      Text('UID: ${auth.currentUser?.uid ?? "null"}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      Text('Role: ${auth.currentUser?.role ?? "null"}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      Text('Store ID (User): ${auth.currentUser?.storeId?.trim() ?? "Missing"}', 
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text('Available Stores in DB (Test):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance.collection('stores').limit(5).get(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) return Text('Error reading stores: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 10));
                          if (!snapshot.hasData) return const Text('Loading...', style: TextStyle(fontSize: 10));
                          if (snapshot.data!.docs.isEmpty) return const Text('NO STORES FOUND IN DB', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 10));
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: snapshot.data!.docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = data['name'] ?? 'Unknown';
                              final match = doc.id == auth.currentUser?.storeId;
                              return Text(
                                '- ${doc.id} ($name) ${match ? "[MATCH!]" : ""}', 
                                style: TextStyle(
                                  fontFamily: 'monospace', 
                                  fontSize: 10,
                                  color: match ? Colors.green : Colors.black87,
                                  fontWeight: match ? FontWeight.bold : FontWeight.normal
                                )
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Trigger a reload of the user profile
                     Provider.of<AuthProvider>(context, listen: false).refreshUser();
                     _fetchStoreDetails(); 
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Store Manager Dashboard', style: TextStyle(fontSize: 16)),
            Text(_store!.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Orders'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Products'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrdersTab(store: _store!),
          _ProductsTab(store: _store!),
        ],
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  final StoreModel store;

  const _OrdersTab({required this.store});

  @override
  Widget build(BuildContext context) {
    // We want to show orders where deliveryPincode is in store.pincodes
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final allOrders = orderProvider.orders; // Assuming this fetches all orders, might need optimization for scale
        
        // Filter orders relevant to this store
        // Logic: Order pincode matches one of the store's pincodes
        final storeOrders = allOrders.where((order) {
           if (order.deliveryPincode == null) return false;
           return store.pincodes.contains(order.deliveryPincode);
        }).toList();

        // Sort by date desc
        storeOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

        if (storeOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No orders for pincodes: ${store.pincodes.join(", ")}', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: storeOrders.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final order = storeOrders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('Order #${order.id.substring(0, 8)}...'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount: ₹${order.totalAmount.toStringAsFixed(2)}'),
                    Text('Pincode: ${order.deliveryPincode}'),
                    Text('Date: ${DateFormat('dd MMM HH:mm').format(order.orderDate)}'),
                  ],
                ),
                trailing: Chip(
                  label: Text(order.status.toUpperCase()),
                  backgroundColor: _getStatusColor(order.status).withOpacity(0.1),
                  labelStyle: TextStyle(color: _getStatusColor(order.status), fontSize: 10),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Color _getStatusColor(String status) {
    switch(status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class _ProductsTab extends StatefulWidget {
  final StoreModel store;

  const _ProductsTab({required this.store});

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}


class _ProductsTabState extends State<_ProductsTab> {
  // Add Product Dialog Logic
  void _showAddProductDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: '\u2022 ');
    final basePriceCtrl = TextEditingController(); // Added Base Price
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final minQtyCtrl = TextEditingController(text: '1');
    
    // Default categories if provider is empty (fallback)
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false); 
    final categories = categoryProvider.categories.isNotEmpty 
        ? categoryProvider.categories.map((c) => c.name).toList() 
        : ['Daily Needs', 'Vegetables', 'Fruits', 'Groceries'];
        
    String selectedCategory = categories.first;
    String selectedUnit = 'Pic';
    bool isLoading = false;
    
    // Image Picking State
    final ImagePicker picker = ImagePicker();
    List<Uint8List> selectedImagesBytes = []; // For preview
    List<XFile> selectedXFiles = []; // For uploading
    
    Future<void> pickImages(StateSetter setDialogState) async {
      try {
        final List<XFile> images = await picker.pickMultiImage();
        if (images.isNotEmpty) {
           if (selectedXFiles.length + images.length > 6) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 6 images allowed')));
             return;
           }
           
           for (var image in images) {
             final bytes = await image.readAsBytes();
             selectedXFiles.add(image);
             selectedImagesBytes.add(bytes);
           }
           setDialogState(() {});
        }
      } catch (e) {
        debugPrint('Error picking images: $e');
      }
    }

    Future<List<String>> uploadImages(String productId) async {
      List<String> downloadUrls = [];
      for (int i = 0; i < selectedImagesBytes.length; i++) {
        try {
          // Create reference: products/{id}/image_{i}.jpg
          final ref = FirebaseStorage.instance
              .ref()
              .child('products')
              .child(productId)
              .child('image_$i.jpg');
          
          await ref.putData(selectedImagesBytes[i], SettableMetadata(contentType: 'image/jpeg'));
          final url = await ref.getDownloadURL();
          downloadUrls.add(url);
        } catch (e) {
          debugPrint('Error uploading image $i: $e');
        }
      }
      return downloadUrls;
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental close during upload
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Product to Store'),
          content: SizedBox(
            width: 550, 
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                      validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      maxLines: 2,
                      onChanged: (value) {
                          if (value.endsWith('\n')) {
                            descCtrl.text = '$value\u2022 ';
                            descCtrl.selection = TextSelection.fromPosition(TextPosition(offset: descCtrl.text.length));
                          } else if (value.isEmpty) {
                            descCtrl.text = '\u2022 ';
                            descCtrl.selection = TextSelection.fromPosition(TextPosition(offset: descCtrl.text.length));
                          }
                      },
                    ),
                    const SizedBox(height: 12),
                    // PRICE ROW
                    Row(
                      children: [
                         Expanded(child: TextFormField(
                          controller: basePriceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Base Price (₹)', 
                            border: OutlineInputBorder(),
                            helperText: 'MPR / Original Price'
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid' : null,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(
                          controller: priceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Selling Price (₹)', 
                            border: OutlineInputBorder(),
                            helperText: 'Final Price for Customer'
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                             final p = double.tryParse(v ?? '');
                             final b = double.tryParse(basePriceCtrl.text.trim()) ?? 0;
                             if (p == null) return 'Invalid';
                             if (p > b && b > 0) return 'Selling > Base';
                             return null;
                          },
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextFormField(
                          controller: stockCtrl,
                          decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          validator: (v) => (int.tryParse(v ?? '') == null) ? 'Invalid' : null,
                        )),
                         const SizedBox(width: 12),
                         Expanded(child: DropdownButtonFormField<String>(
                          value: selectedUnit,
                          decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                          items: ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm', 'Box', 'Dozen', 'Set', 'Packet', 'Gram'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (v) => setState(() => selectedUnit = v!),
                        )),
                      ],
                    ),
                     const SizedBox(height: 12),
                    TextFormField(
                       controller: minQtyCtrl,
                       decoration: InputDecoration(labelText: 'Minimum Quantity', border: const OutlineInputBorder(), suffixText: selectedUnit),
                       keyboardType: TextInputType.number,
                       validator: (v) => (v?.isEmpty == true || int.tryParse(v!) == null || int.parse(v) < 1) ? 'Min 1' : null,
                    ),
                     const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      isExpanded: true,
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => selectedCategory = v!),
                    ),
                    const SizedBox(height: 16),
                    
                    // IMAGE PICKER UI
                    const Text('Product Images (Max 6)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Picker Button
                        if (selectedImagesBytes.length < 6)
                          InkWell(
                            onTap: () => pickImages(setState),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                border: Border.all(color: Colors.grey[400]!, style: BorderStyle.solid),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Colors.grey),
                                  SizedBox(height: 4),
                                  Text('Add', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                          
                        // Image Previews
                        ...selectedImagesBytes.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final Uint8List bytes = entry.value;
                          return Stack(
                            children: [
                               Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedImagesBytes.removeAt(index);
                                      selectedXFiles.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState!.validate()) {
                    if (selectedImagesBytes.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one image')));
                      return;
                    }
                  
                  setState(() => isLoading = true);
                  
                  try {
                    // 1. Create Document first to get ID
                    final docRef = await FirebaseFirestore.instance.collection('products').add({
                      'name': nameCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'basePrice': double.parse(basePriceCtrl.text.trim()),
                      'price': double.parse(priceCtrl.text.trim()),
                      'mrp': double.parse(basePriceCtrl.text.trim()), // Synced with basePrice
                      'stock': int.parse(stockCtrl.text.trim()),
                      'category': selectedCategory,
                      'unit': selectedUnit,
                      'imageUrl': '', // Placeholder, update later
                      'imageUrls': [], // Placeholder
                      'storeIds': [widget.store.id],
                      'sellerId': 'store_manager', // Identify source
                      'isFeatured': false,
                      'isHotDeal': false, 
                      'minimumQuantity': int.parse(minQtyCtrl.text),
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    // 2. Upload Images
                    final urls = await uploadImages(docRef.id);
                    
                    // 3. Update Document with URLs
                    await docRef.update({
                      'imageUrl': urls.isNotEmpty ? urls.first : '',
                      'imageUrls': urls,
                    });

                     if (mounted) {
                       Navigator.pop(context);
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added successfully!')));
                     }
                  } catch (e) {
                     setState(() => isLoading = false);
                     debugPrint('Error adding product: $e');
                     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, Product product) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: product.name);
    final descCtrl = TextEditingController(text: product.description);
    final basePriceCtrl = TextEditingController(text: product.basePrice.toString());
    final priceCtrl = TextEditingController(text: product.price.toString());
    final stockCtrl = TextEditingController(text: product.stock.toString());
    final minQtyCtrl = TextEditingController(text: (product.minimumQuantity ?? 1).toString());
    final imageUrlCtrl = TextEditingController(text: product.imageUrl); // Fallback

    String selectedCategory = product.category ?? 'Daily Needs';
    String selectedUnit = product.unit ?? 'Pic';
    
    // Image State
    List<String> keptImageUrls = List.from(product.imageUrls ?? (product.imageUrl.isNotEmpty ? [product.imageUrl] : []));
    List<Uint8List> newImagesBytes = [];
    List<XFile> newImageFiles = [];
    
    bool isLoading = false;
    final ImagePicker picker = ImagePicker();

    // Helper: Pick Images
    Future<void> pickImages(StateSetter setDialogState) async {
       try {
         final int currentCount = keptImageUrls.length + newImagesBytes.length;
         if (currentCount >= 6) {
           if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 6 images allowed')));
           return;
         }
         
         final List<XFile> picked = await picker.pickMultiImage();
         if (picked.isNotEmpty) {
           int canAdd = 6 - currentCount;
           final toAdd = picked.take(canAdd).toList();
           
           for (var file in toAdd) {
             final bytes = await file.readAsBytes();
             newImagesBytes.add(bytes);
             newImageFiles.add(file);
           }
           setDialogState(() {});
         }
       } catch (e) {
         debugPrint('Error picking images: $e');
       }
    }

    // Helper: Upload New Images
    Future<List<String>> uploadNewImages() async {
      List<String> urls = [];
      for (int i = 0; i < newImagesBytes.length; i++) {
         try {
           // Use timestamp to ensure unique names for updates
           String fileName = 'image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
           final ref = FirebaseStorage.instance
               .ref()
               .child('products')
               .child(product.id)
               .child(fileName);
           
           await ref.putData(newImagesBytes[i]);
           final url = await ref.getDownloadURL();
           urls.add(url);
         } catch (e) {
           debugPrint('Error uploading image $i: $e');
         }
      }
      return urls;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Product'),
          content: SizedBox(
            width: 500,
            child: Form(
               key: formKey,
               child: SingleChildScrollView(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // -- IMAGES SECTION --
                     const Text('Product Images (Max 6)', style: TextStyle(fontWeight: FontWeight.bold)),
                     const SizedBox(height: 8),
                     Wrap(
                       spacing: 8,
                       runSpacing: 8,
                       children: [
                         // 1. Existing Images
                         ...keptImageUrls.asMap().entries.map((entry) {
                           int idx = entry.key;
                           String url = entry.value;
                           return Stack(
                             children: [
                               Container(
                                 width: 80, height: 80,
                                 decoration: BoxDecoration(
                                   borderRadius: BorderRadius.circular(8),
                                   image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                                   border: Border.all(color: Colors.grey[300]!)
                                 ),
                               ),
                               Positioned(
                                 top: 0, right: 0,
                                 child: InkWell(
                                   onTap: () => setState(() => keptImageUrls.removeAt(idx)),
                                   child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                                 ),
                               )
                             ],
                           );
                         }),
                         
                         // 2. New Images
                         ...newImagesBytes.asMap().entries.map((entry) {
                            int idx = entry.key;
                            return Stack(
                             children: [
                               Container(
                                 width: 80, height: 80,
                                 decoration: BoxDecoration(
                                   borderRadius: BorderRadius.circular(8),
                                   image: DecorationImage(image: MemoryImage(entry.value), fit: BoxFit.cover),
                                   border: Border.all(color: Colors.green[300]!) // Green border for new
                                 ),
                               ),
                               Positioned(
                                 top: 0, right: 0,
                                 child: InkWell(
                                   onTap: () => setState(() {
                                     newImagesBytes.removeAt(idx);
                                     newImageFiles.removeAt(idx);
                                   }),
                                   child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                                 ),
                               )
                             ],
                           );
                         }),

                         // 3. Add Button
                         if (keptImageUrls.length + newImagesBytes.length < 6)
                           InkWell(
                             onTap: () => pickImages(setState),
                             child: Container(
                               width: 80, height: 80,
                               decoration: BoxDecoration(
                                 color: Colors.grey[100],
                                 borderRadius: BorderRadius.circular(8),
                                 border: Border.all(color: Colors.grey[400]!, style: BorderStyle.solid),
                               ),
                               child: const Icon(Icons.add_a_photo, color: Colors.grey),
                             ),
                           ),
                       ],
                     ),
                     const SizedBox(height: 16),

                     // -- DETAILS SECTION --
                     TextFormField(
                       controller: nameCtrl,
                       decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                       validator: (v) => v!.isEmpty ? 'Required' : null,
                     ),
                     const SizedBox(height: 12),
                     TextFormField(
                       controller: descCtrl,
                       decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                       maxLines: 3,
                     ),
                     const SizedBox(height: 12),
                     Row(
                       children: [
                         Expanded(
                           child: TextFormField(
                             controller: basePriceCtrl,
                             decoration: const InputDecoration(labelText: 'Base Price (₹)', border: OutlineInputBorder()),
                             keyboardType: TextInputType.number,
                             validator: (v) => v!.isEmpty ? 'Required' : null,
                           ),
                         ),
                         const SizedBox(width: 12),
                         Expanded(
                           child: TextFormField(
                             controller: priceCtrl,
                             decoration: const InputDecoration(labelText: 'Selling Price (₹)', border: OutlineInputBorder()),
                             keyboardType: TextInputType.number,
                             validator: (v) {
                               if (v == null || v.isEmpty) return 'Required';
                               double? sPrice = double.tryParse(v);
                               double? bPrice = double.tryParse(basePriceCtrl.text);
                               if (sPrice != null && bPrice != null && sPrice > bPrice) {
                                  return 'Must be <= Base';
                               }
                               return null;
                             },
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 12),
                     Row(
                       children: [
                         Expanded(
                           child: TextFormField(
                             controller: stockCtrl,
                             decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()),
                             keyboardType: TextInputType.number,
                             validator: (v) => v!.isEmpty ? 'Required' : null,
                           ),
                         ),
                         const SizedBox(width: 12),
                         Expanded(
                           child: DropdownButtonFormField<String>(
                             value: selectedUnit,
                             items: ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm', 'Box', 'Dozen', 'Set', 'Packet', 'Gram'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                             onChanged: (v) => setState(() => selectedUnit = v!),
                             decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 12),
                     TextFormField(
                       controller: minQtyCtrl,
                       decoration: InputDecoration(labelText: 'Minimum Quantity', border: const OutlineInputBorder(), suffixText: selectedUnit),
                       keyboardType: TextInputType.number,
                       validator: (v) => (v?.isEmpty == true || int.tryParse(v!) == null || int.parse(v) < 1) ? 'Min 1' : null,
                     ),
                     const SizedBox(height: 12),
                     // Category Dropdown (Simplified)
                      Consumer<CategoryProvider>(
                        builder: (ctx, catProvider, _) {
                            final cats = catProvider.categories.map((c) => c.name).toSet().toList(); // Unique
                            if (cats.isEmpty) cats.add('Daily Needs');
                            // Ensure selected is in list
                            if (!cats.contains(selectedCategory)) cats.add(selectedCategory);
                            
                            return DropdownButtonFormField<String>(
                              value: selectedCategory,
                              items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setState(() => selectedCategory = v!),
                              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                            );
                        }
                      ),
                   ],
                 ),
               ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                 if (formKey.currentState!.validate()) {
                    setState(() => isLoading = true);
                    try {
                      // 1. Upload Any New Images
                      List<String> newUrls = await uploadNewImages();
                      
                      // 2. Combine with Kept Images
                      List<String> finalImageUrls = [...keptImageUrls, ...newUrls];
                      
                      // 3. Update Firestore
                      await FirebaseFirestore.instance.collection('products').doc(product.id).update({
                        'name': nameCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'basePrice': double.parse(basePriceCtrl.text.trim()),
                        'price': double.parse(priceCtrl.text.trim()),
                        // Auto-update MRP to base price if not explicitly managed, or keep logic same as add
                        'mrp': double.parse(basePriceCtrl.text.trim()), 
                        'stock': int.parse(stockCtrl.text.trim()),
                        'minimumQuantity': int.parse(minQtyCtrl.text.trim()),
                        'category': selectedCategory,
                        'unit': selectedUnit,
                        'imageUrl': finalImageUrls.isNotEmpty ? finalImageUrls.first : '',
                        'imageUrls': finalImageUrls,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated successfully!')));
                      }
                    } catch (e) {
                      setState(() => isLoading = false);
                      debugPrint('Error updating product: $e');
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                 }
              },
              child: isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Update Product'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Wrap in Scaffold to support FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProductDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        backgroundColor: Colors.blue,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, _) {
          // Filter products available in this store
          final storeProducts = productProvider.products.where((p) {
            return p.storeIds.contains(widget.store.id);
          }).toList();

          if (storeProducts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No products assigned to this store.', 
                     textAlign: TextAlign.center,
                     style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showAddProductDialog(context), 
                    icon: const Icon(Icons.add), 
                    label: const Text('Add First Product')
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: storeProducts.length,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Padding for FAB
            itemBuilder: (context, index) {
              final product = storeProducts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                      image: product.imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(product.imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: product.imageUrl.isEmpty ? const Icon(Icons.image) : null,
                  ),
                  title: Text(product.name),
                  subtitle: Text('Stock: ${product.stock} ${product.unit ?? ''} | Price: ₹${product.price}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      _showEditProductDialog(context, product);
                    },
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
