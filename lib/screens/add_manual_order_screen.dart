import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';

class AddManualOrderScreen extends StatefulWidget {
  const AddManualOrderScreen({super.key});

  @override
  State<AddManualOrderScreen> createState() => _AddManualOrderScreenState();
}

class _AddManualOrderScreenState extends State<AddManualOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _stateController = TextEditingController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _selectedItems = [];
  List<Product> _searchResults = [];
  List<Product> _initialProducts = []; // NEW: Cache for initial load
  bool _isSaving = false;
  bool _isSearching = false;
  Timer? _searchDebounce; // NEW: Debounce timer

  @override
  void initState() {
    super.initState();
    // Pre-fill state if user is a State Admin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isStateAdmin && auth.currentUser?.assignedState != null) {
        _stateController.text = auth.currentUser!.assignedState!;
      }
      _loadInitialProducts(); // NEW: Load products on start
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _stateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialProducts() async {
    setState(() => _isSearching = true);
    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      // Fetch latest 50 products initially to show something
      final results = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      final products = results.docs.map((doc) => Product.fromMap(doc.id, doc.data())).toList();
      
      setState(() {
        _initialProducts = products;
        _searchResults = products;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Error loading initial products: $e');
      setState(() => _isSearching = false);
    }
  }

  double get _totalAmount {
    return _selectedItems.fold(
      0,
      (sum, item) => sum + (item['price'] * item['quantity']),
    );
  }

  double get _totalDeliveryFee {
    return _selectedItems.fold(
      0.0,
      (sum, item) => sum + ((item['deliveryFeeOverride'] ?? 0.0) * item['quantity']),
    );
  }

  void _addItem(Product product) {
    setState(() {
      final index = _selectedItems.indexWhere((item) => item['productId'] == product.id);
      if (index != -1) {
        _selectedItems[index]['quantity']++;
      } else {
        _selectedItems.add({
          'productId': product.id,
          'productName': product.name,
          'productImageUrl': product.imageUrl,
          'price': product.price,
          'basePrice': product.basePrice,
          'adminProfitPercentage': product.adminProfitPercentage, // Inherit commission
          'deliveryFeeOverride': product.deliveryFeeOverride, // Inherit delivery fee override
          'quantity': 1,
          'sellerId': product.sellerId,
          'storeIds': product.storeIds,
          'unit': product.unit,
        });
      }
      _searchResults.clear();
      _searchController.clear();
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final newQty = _selectedItems[index]['quantity'] + delta;
      if (newQty > 0) {
        _selectedItems[index]['quantity'] = newQty;
      } else {
        _selectedItems.removeAt(index);
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchProducts(query);
    });
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = _initialProducts;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final results = await productProvider.searchProductsGlobal(query.trim());
      
      // Also try local search on initial products for faster responsiveness
      final localResults = _initialProducts.where((p) => 
        p.name.toLowerCase().contains(query.toLowerCase().trim())
      ).toList();

      // Merge and remove duplicates
      final Map<String, Product> combined = {};
      for (var p in localResults) { combined[p.id] = p; }
      for (var p in results) { combined[p.id] = p; }

      setState(() {
        _searchResults = combined.values.toList();
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() => _isSearching = false);
    }
  }

  Future<void> _syncSearchKeywords() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Updating search index... please wait ⏳')),
    );

    try {
      final firestore = FirebaseFirestore.instance;
      final productsSnapshot = await firestore.collection('products').get();
      
      final batch = firestore.batch();
      int count = 0;
      
      for (var doc in productsSnapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? '';
        
        // Generate keywords using the unified logic
        final lowerName = name.toLowerCase();
        final List<String> keywords = [lowerName];
        // Split by non-alphanumeric characters for better word extraction
        final List<String> words = lowerName.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
        
        for (final word in words) {
          if (!keywords.contains(word)) keywords.add(word);
          for (int i = 1; i <= word.length; i++) {
            final prefix = word.substring(0, i);
            if (!keywords.contains(prefix)) keywords.add(prefix);
          }
        }
        
        batch.update(doc.reference, {'searchKeywords': keywords});
        count++;
      }
      
      await batch.commit();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Success! $count products updated. 🎉'), backgroundColor: Colors.green),
      );
      
      // Reload initial products to reflect changes
      await _loadInitialProducts();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields correctly'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one product')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final auth = context.read<AuthProvider>();
      final adminId = auth.currentUser?.uid;
      
      final sellerIds = _selectedItems
          .map((item) => item['sellerId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();

      final orderData = {
        'userId': 'guest_${_phoneController.text.trim()}',
        'userName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'deliveryAddress': _addressController.text.trim(),
        'deliveryPincode': _pincodeController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'state': _stateController.text.trim(),
        'items': _selectedItems,
        'sellerIds': sellerIds,
        'totalAmount': _totalAmount,
        'deliveryFee': _totalDeliveryFee, // Save the calculated delivery fee
        'status': 'pending',
        'orderDate': FieldValue.serverTimestamp(),
        'isGuest': true,
        'createdBy': adminId,
        'statusHistory': {
          'pending': FieldValue.serverTimestamp(),
        },
        'paymentStatus': 'pending',
        'paymentMethod': 'COD (Manual)',
      };

      await FirebaseFirestore.instance.collection('orders').add(orderData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manual Order Created!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save order: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Add Guest Order (Manual)'),
        elevation: 0,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar (Desktop/Tablet) or Main View (Mobile)
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Customer Details
                    _buildSectionHeader('Customer Details', Icons.person_outline),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(Icons.badge_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Full Address',
                                prefixIcon: Icon(Icons.location_on_outlined),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _pincodeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Pincode',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (v) => v!.isEmpty ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _stateController,
                                    decoration: const InputDecoration(
                                      labelText: 'State',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) => v!.isEmpty ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Product Search
                    _buildSectionHeader('Add Products', Icons.add_shopping_cart),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search products by name...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _isSearching 
                                  ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                                : (_searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchResults = _initialProducts; })) : null),
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: _onSearchChanged,
                            ),
                            const SizedBox(height: 8),
                            // NEW: Sync button for fixing old products
                            TextButton.icon(
                              onPressed: _syncSearchKeywords,
                              icon: const Icon(Icons.sync, size: 16),
                              label: const Text('Update Search (Sync)', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), foregroundColor: Colors.blue),
                            ),
                            if (_searchResults.isNotEmpty)
                              Container(
                                constraints: const BoxConstraints(maxHeight: 300),
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _searchResults.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final p = _searchResults[i];
                                    return ListTile(
                                      leading: p.imageUrl != null 
                                        ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(p.imageUrl!, width: 40, height: 40, fit: BoxFit.cover))
                                        : const Icon(Icons.image_outlined),
                                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('₹${p.price} / ${p.unit}'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                                        onPressed: () => _addItem(p),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            if (_searchResults.isEmpty && _searchController.text.isNotEmpty && !_isSearching)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No products found', style: TextStyle(color: Colors.grey)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 3: Selected Items (for mobile)
                    if (MediaQuery.of(context).size.width <= 900) ...[
                      _buildSectionHeader('Selected Items (${_selectedItems.length})', Icons.shopping_basket_outlined),
                      if (_selectedItems.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No items added yet', style: TextStyle(color: Colors.grey))))
                      else
                        _buildSelectedItemsList(),
                      const SizedBox(height: 100), // Space for bottom bar
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Right Sidebar (Order Summary) - Only for Desktop/Large screens
          if (MediaQuery.of(context).size.width > 900)
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Divider(height: 32),
                    Expanded(child: _buildSelectedItemsList()),
                    const Divider(height: 32),
                    _buildTotalFooter(),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width <= 900
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: SafeArea(child: _buildTotalFooter()),
            )
          : null,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSelectedItemsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: MediaQuery.of(context).size.width > 900 ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
      itemCount: _selectedItems.length,
      itemBuilder: (ctx, i) {
        final item = _selectedItems[i];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade100)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item['productImageUrl'] != null 
                ? Image.network(item['productImageUrl'], width: 50, height: 50, fit: BoxFit.cover)
                : const Icon(Icons.image, size: 50, color: Colors.grey),
            ),
            title: Text(item['productName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('₹${item['price']} x ${item['quantity']} = ₹${(item['price'] * item['quantity']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(iconSize: 20, icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => _updateQuantity(i, -1)),
                Text('${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(iconSize: 20, icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _updateQuantity(i, 1)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTotalFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Delivery Fee:', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Text('₹${_totalDeliveryFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Amount:', style: TextStyle(color: Colors.grey, fontSize: 14)),
            Text('₹${(_totalAmount + _totalDeliveryFee).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('CREATE GUEST ORDER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
