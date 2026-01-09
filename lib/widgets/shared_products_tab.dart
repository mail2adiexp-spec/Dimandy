import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/category_provider.dart';

class SharedProductsTab extends StatefulWidget {
  final bool canManage;
  final String? sellerId; // If provided, limits to specific seller (e.g. for seller dashboard)

  const SharedProductsTab({
    Key? key,
    this.canManage = true,
    this.sellerId,
  }) : super(key: key);

  @override
  State<SharedProductsTab> createState() => _SharedProductsTabState();
}

class _SharedProductsTabState extends State<SharedProductsTab> {
  // Search and Filter State
  String _productSearchQuery = '';
  String? _selectedProductCategory;
  
  // Advanced Filters
  double? _minProductPrice;
  double? _maxProductPrice;
  String _stockFilter = 'All'; // All, Low, Out, InStock
  final Set<String> _selectedProductCategories = {};
  String _featuredFilter = 'All'; // All, Featured, NonFeatured
  String _hotDealFilter = 'All'; // All, HotDeal, NonHotDeal
  String _customerChoiceFilter = 'All'; // All, CustomerChoice, NonCustomerChoice
  DateTime? _productStartDate;
  DateTime? _productEndDate;

  // Selection Mode
  bool _isProductSelectionMode = false;
  Set<String> _selectedProductIds = {};

  // Image Picker
  final ImagePicker _picker = ImagePicker();

  late Stream<QuerySnapshot> _productsStream;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  @override
  void didUpdateWidget(SharedProductsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sellerId != oldWidget.sellerId) {
      _initializeStream();
    }
  }

  void _initializeStream() {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true);

    if (widget.sellerId != null) {
      query = query.where('sellerId', isEqualTo: widget.sellerId);
    }

    _productsStream = query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var products = snapshot.data?.docs ?? [];

        // Client-side filtering
        products = _filterProducts(products);

        return CustomScrollView(
          slivers: [
            // Header with Search, Filters, and Actions
            SliverToBoxAdapter(
              child: _buildHeader(products),
            ),
            
            // Products Grid
            if (products.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(),
              )
            else
              _buildProductsGrid(products),
          ],
        );
      },
    );
  }

  Stream<QuerySnapshot> _getProductsStream() {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true);

    if (widget.sellerId != null) {
      query = query.where('sellerId', isEqualTo: widget.sellerId);
    }

    return query.snapshots();
  }

  List<QueryDocumentSnapshot> _filterProducts(List<QueryDocumentSnapshot> products) {
    return products.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Search
      if (_productSearchQuery.isNotEmpty) {
        final name = (data['name'] as String?)?.toLowerCase() ?? '';
        if (!name.contains(_productSearchQuery.toLowerCase())) return false;
      }

      // Exact Category match (Dropdown)
      if (_selectedProductCategory != null) {
        if (data['category'] != _selectedProductCategory) return false;
      }
      
      // Price Range
      final price = (data['price'] as num?)?.toDouble() ?? 0;
      if (_minProductPrice != null && price < _minProductPrice!) return false;
      if (_maxProductPrice != null && price > _maxProductPrice!) return false;
      
      // Stock
      final stock = (data['stock'] as num?)?.toInt() ?? 0;
      if (_stockFilter == 'Low' && stock >= 10) return false;
      if (_stockFilter == 'Out' && stock != 0) return false;
      if (_stockFilter == 'InStock' && stock <= 0) return false;
      
      // Multi-Category
      if (_selectedProductCategories.isNotEmpty) {
        final category = data['category'] as String?;
        if (category == null || !_selectedProductCategories.contains(category)) {
          return false;
        }
      }
      
      // Featured
      final isFeatured = data['isFeatured'] as bool? ?? false;
      if (_featuredFilter == 'Featured' && !isFeatured) return false;
      if (_featuredFilter == 'Featured' && !isFeatured) return false;
      if (_featuredFilter == 'NonFeatured' && isFeatured) return false;

      // Hot Deal
      final isHotDeal = data['isHotDeal'] as bool? ?? false;
      if (_hotDealFilter == 'HotDeal' && !isHotDeal) return false;
      if (_hotDealFilter == 'NonHotDeal' && isHotDeal) return false;

      // Customer Choice
      final isCustomerChoice = data['isCustomerChoice'] as bool? ?? false;
      if (_customerChoiceFilter == 'CustomerChoice' && !isCustomerChoice) return false;
      if (_customerChoiceFilter == 'NonCustomerChoice' && isCustomerChoice) return false;
      
      // Date Range
      if (_productStartDate != null || _productEndDate != null) {
         final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
         if (createdAt != null) {
           if (_productStartDate != null && createdAt.isBefore(_productStartDate!)) {
             return false;
           }
           if (_productEndDate != null && createdAt.isAfter(_productEndDate!.add(const Duration(days: 1)))) {
             return false;
           }
         }
      }

      return true;
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(List<QueryDocumentSnapshot> products) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top Row: Count and Actions
          // Top Row: Count and Actions
          MediaQuery.of(context).size.width < 600
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Total Products: ${products.length}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!_isProductSelectionMode && widget.canManage)
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _isProductSelectionMode = true),
                            icon: const Icon(Icons.check_box_outlined),
                            label: const Text('Select Mode'),
                          ),
                        if (widget.canManage)
                          ElevatedButton.icon(
                            onPressed: _showAddProductDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Products: ${products.length}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        if (!_isProductSelectionMode && widget.canManage)
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _isProductSelectionMode = true),
                            icon: const Icon(Icons.check_box_outlined),
                            label: const Text('Select Mode'),
                          ),
                        const SizedBox(width: 8),
                        if (widget.canManage)
                          ElevatedButton.icon(
                            onPressed: _showAddProductDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
          
          // Bulk Operations Toolbar
          if(_isProductSelectionMode && widget.canManage) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _selectedProductIds.length == products.length && products.isNotEmpty,
                    tristate: true,
                    onChanged: (selected) {
                      setState(() {
                         if (selected == true) {
                           _selectedProductIds = products.map((p) => p.id).toSet();
                         } else {
                           _selectedProductIds.clear();
                         }
                      });
                    },
                  ),
                  Text(
                    _selectedProductIds.isEmpty
                        ? 'Select All'
                        : '${_selectedProductIds.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Bulk Edit',
                    onPressed: _selectedProductIds.isEmpty ? null : _showBulkEditProductsDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Bulk Delete',
                    onPressed: _selectedProductIds.isEmpty ? null : _bulkDeleteProducts,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Exit Selection Mode',
                    onPressed: () {
                      setState(() {
                        _isProductSelectionMode = false;
                        _selectedProductIds.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Search and Category
          MediaQuery.of(context).size.width < 600
              ? Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) => setState(() => _productSearchQuery = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        hintText: 'Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      value: _selectedProductCategory,
                      menuMaxHeight: 300,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Categories')),
                        ...Provider.of<CategoryProvider>(context).categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                      ],
                      onChanged: (val) => setState(() => _selectedProductCategory = val),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) => setState(() => _productSearchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          hintText: 'Category',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        value: _selectedProductCategory,
                        menuMaxHeight: 300,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Categories')),
                          ...Provider.of<CategoryProvider>(context).categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                        ],
                        onChanged: (val) => setState(() => _selectedProductCategory = val),
                      ),
                    ),
                  ],
                ),
          
          // Advanced Filters Panel
           const SizedBox(height: 8),
            ExpansionTile(
              title: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 20),
                  const SizedBox(width: 8),
                  const Text('Advanced Filters'),
                  if (_minProductPrice != null || 
                      _maxProductPrice != null ||
                      _stockFilter != 'All' ||
                      _selectedProductCategories.isNotEmpty ||
                      _stockFilter != 'All' ||
                      _selectedProductCategories.isNotEmpty ||
                      _featuredFilter != 'All' ||
                      _hotDealFilter != 'All' ||
                      _customerChoiceFilter != 'All') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ],
              ),
              children: [
                 Padding(
                   padding: const EdgeInsets.all(16),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       // Price Range
                       const Text('Price Range', style: TextStyle(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 8),
                       Row(
                         children: [
                           Expanded(
                             child: TextField(
                               decoration: const InputDecoration(labelText: 'Min Price', prefixText: '₹', border: OutlineInputBorder(), isDense: true),
                               keyboardType: TextInputType.number,
                               onChanged: (v) => setState(() => _minProductPrice = double.tryParse(v)),
                             ),
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                               child: TextField(
                                 decoration: const InputDecoration(labelText: 'Max Price', prefixText: '₹', border: OutlineInputBorder(), isDense: true),
                                 keyboardType: TextInputType.number,
                                 onChanged: (v) => setState(() => _maxProductPrice = double.tryParse(v)),
                               ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 16),
                       // Stock
                       const Text('Stock Status', style: TextStyle(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 8),
                       DropdownButtonFormField<String>(
                         value: _stockFilter,
                         decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                         items: const [
                           DropdownMenuItem(value: 'All', child: Text('All')),
                           DropdownMenuItem(value: 'Low', child: Text('Low Stock (< 10)')),
                           DropdownMenuItem(value: 'Out', child: Text('Out of Stock')),
                           DropdownMenuItem(value: 'InStock', child: Text('In Stock')),
                         ],
                         onChanged: (v) => setState(() => _stockFilter = v!),
                       ),
                       const SizedBox(height: 16),
                       // Multi-Category
                        const Text('Categories (Multi-select)', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: Provider.of<CategoryProvider>(context).categories.map((cat) {
                            return FilterChip(
                              label: Text(cat.name),
                              selected: _selectedProductCategories.contains(cat.name),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedProductCategories.add(cat.name);
                                  } else {
                                    _selectedProductCategories.remove(cat.name);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        // Featured
                        const Text('Featured Status', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _featuredFilter,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          items: const [
                             DropdownMenuItem(value: 'All', child: Text('All')),
                             DropdownMenuItem(value: 'Featured', child: Text('Featured Only')),
                             DropdownMenuItem(value: 'NonFeatured', child: Text('Non-Featured')),
                          ],
                          onChanged: (v) => setState(() => _featuredFilter = v!),
                        ),
                        const SizedBox(height: 16),
                        // Hot Deal
                        const Text('Hot Deal Status', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _hotDealFilter,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          items: const [
                             DropdownMenuItem(value: 'All', child: Text('All')),
                             DropdownMenuItem(value: 'HotDeal', child: Text('Hot Deal Only')),
                             DropdownMenuItem(value: 'NonHotDeal', child: Text('Non-Hot Deal')),
                          ],
                          onChanged: (v) => setState(() => _hotDealFilter = v!),
                        ),
                        const SizedBox(height: 16),
                        // Customer Choice
                        const Text('Customer Choice Status', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _customerChoiceFilter,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          items: const [
                             DropdownMenuItem(value: 'All', child: Text('All')),
                             DropdownMenuItem(value: 'CustomerChoice', child: Text('Customer Choice Only')),
                             DropdownMenuItem(value: 'NonCustomerChoice', child: Text('Non-Customer Choice')),
                          ],
                          onChanged: (v) => setState(() => _customerChoiceFilter = v!),
                        ),
                        const SizedBox(height: 16),
                        // Clear All
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _minProductPrice = null;
                                _maxProductPrice = null;
                                _stockFilter = 'All';
                                _selectedProductCategories.clear();
                                _stockFilter = 'All';
                                _selectedProductCategories.clear();
                                _featuredFilter = 'All';
                                _hotDealFilter = 'All';
                                _customerChoiceFilter = 'All';
                              });
                            },
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Clear All Filters'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                          ),
                        ),
                     ],
                   ),
                 ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(List<QueryDocumentSnapshot> products) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Added 80 bottom padding
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.65, // Slightly taller cards to accommodate details
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = products[index];
            final data = product.data() as Map<String, dynamic>;
            final images = data['images'] as List<dynamic>? ?? [];
            final imageUrl = images.isNotEmpty ? images[0] : null;
            
            return Stack(
              children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: _isProductSelectionMode && _selectedProductIds.contains(product.id)
                  ? const BorderSide(color: Colors.blue, width: 3)
                  : BorderSide.none,
              ),
              child: InkWell(
                onTap: _isProductSelectionMode
                    ? () {
                        setState(() {
                          if (_selectedProductIds.contains(product.id)) {
                             _selectedProductIds.remove(product.id);
                          } else {
                             _selectedProductIds.add(product.id);
                          }
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                        ),
                        child: imageUrl != null 
                             ? ClipRRect(
                                 borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                                 child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.image_not_supported, size: 40)),
                               )
                             : const Icon(Icons.inventory_2, size: 40),
                      ),
                    ),
                    // Details
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(data['price'] ?? 0), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(data['isFeatured'] == true ? Icons.star : Icons.star_border, size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Expanded(child: Text('Stock: ${data['stock'] ?? 0}', style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (widget.canManage)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditProductDialog(product.id, data);
                                } else if (value == 'delete') {
                                  _deleteProduct(product.id, data['name']);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                              icon: const Icon(Icons.more_vert),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
             if (_isProductSelectionMode)
               Positioned(
                 top: 8,
                 right: 8,
                 child: Container(
                   decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0,2))]),
                   child: Checkbox(
                     value: _selectedProductIds.contains(product.id),
                     onChanged: (selected) {
                       setState(() {
                         if (selected == true) {
                           _selectedProductIds.add(product.id);
                         } else {
                           _selectedProductIds.remove(product.id);
                         }
                       });
                     },
                     shape: const CircleBorder(),
                   ),
                 ),
               ),
          ],
        );
          },
          childCount: products.length,
        ),
      ),
    );
  }

  // Dialogs and Logic

  Future<void> _deleteProduct(String productId, String? name) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Product'),
          content: Text('Delete "${name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await FirebaseFirestore.instance.collection('products').doc(productId).delete();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted successfully')));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
  }

  void _showAddProductDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final mrpCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final minQtyCtrl = TextEditingController(text: '1');
    
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final categories = categoryProvider.categories.map((c) => c.name).toList();
    
    String selectedCategory = categories.isNotEmpty 
        ? (categories.contains('Daily Needs') ? 'Daily Needs' : categories.first) 
        : 'Daily Needs';
        
    if (categories.isEmpty) {
       // Fallback or fetch if empty (though provider should be loaded at app start)
       // For now, assume loaded or allow user to add?
       // This might be why "Daily Needs" hardcoded is safer as default?
       // But we want DYNAMIC.
    }
    
    String selectedUnit = 'Pic';
    bool isFeatured = false;
    bool isHotDeal = false;
    bool isCustomerChoice = false;
    bool isLoading = false;
    List<Uint8List> selectedImages = [];

    Future<void> pickImages(StateSetter setState) async {
      try {
        final List<XFile> images = await _picker.pickMultiImage();
        if (images.isNotEmpty && images.length <= 6) {
          final List<Uint8List> imageBytes = [];
          for (var image in images) {
            final bytes = await image.readAsBytes();
            imageBytes.add(bytes);
          }
          setState(() {
            selectedImages = imageBytes;
          });
        } else if (images.length > 6) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 6 images allowed')));
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
        }
      }
    }

    Future<List<String>> uploadImages(String productId) async {
       List<String> imageUrls = [];
       for (int i = 0; i < selectedImages.length; i++) {
         try {
           final ref = FirebaseStorage.instance.ref().child('products').child(productId).child('image_$i.jpg');
           await ref.putData(selectedImages[i]);
           final url = await ref.getDownloadURL();
           imageUrls.add(url);
         } catch (e) {
           debugPrint('Error uploading image $i: $e');
         }
       }
       return imageUrls;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width > 700 ? 700 : double.maxFinite,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Add New Product', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()),
                      validator: (v) => (v?.isEmpty == true || v!.length < 3) ? 'Required, min 3 chars' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: mrpCtrl,
                            decoration: const InputDecoration(labelText: 'MRP (Original Price)', border: OutlineInputBorder(), prefixText: '₹'),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                                final p = double.tryParse(priceCtrl.text) ?? 0;
                                final m = double.tryParse(val) ?? 0;
                                if (m > p && p > 0) {
                                   setState(() => isHotDeal = true);
                                }
                            }
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            decoration: const InputDecoration(labelText: 'Selling Price *', border: OutlineInputBorder(), prefixText: '₹'),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v?.isEmpty == true || double.tryParse(v!) == null) ? 'Invalid Price' : null,
                            onChanged: (val) {
                                final p = double.tryParse(val) ?? 0;
                                final m = double.tryParse(mrpCtrl.text) ?? 0;
                                if (m > p && p > 0) {
                                   setState(() => isHotDeal = true);
                                }
                            }
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: stockCtrl,
                            decoration: const InputDecoration(labelText: 'Stock *', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v?.isEmpty == true || int.tryParse(v!) == null) ? 'Invalid Stock' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                       controller: minQtyCtrl,
                       decoration: const InputDecoration(labelText: 'Minimum Quantity', border: OutlineInputBorder()),
                       keyboardType: TextInputType.number,
                       validator: (v) => (v?.isEmpty == true || int.tryParse(v!) == null || int.parse(v) < 1) ? 'Min 1' : null,
                    ),
                    const SizedBox(height: 16),
                    MediaQuery.of(context).size.width < 600
                    ? Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                            items: Provider.of<CategoryProvider>(context, listen: false).categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                            onChanged: (v) => setState(() => selectedCategory = v!),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedUnit,
                            decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                            items: ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (v) => setState(() => selectedUnit = v!),
                          ),
                        ],
                      )
                    : Row(
                      children: [
                        Expanded(child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                          items: Provider.of<CategoryProvider>(context, listen: false).categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                          onChanged: (v) => setState(() => selectedCategory = v!),
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: DropdownButtonFormField<String>(
                          value: selectedUnit,
                          decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                          items: ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (v) => setState(() => selectedUnit = v!),
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(title: const Text('Featured Product'), value: isFeatured, onChanged: (v) => setState(() => isFeatured = v)),
                    // Auto-calculated Hot Deal based on MRP > Price
                    // Customer Choice is now based on sales count
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => pickImages(setState),
                      icon: const Icon(Icons.image),
                      label: Text(selectedImages.isEmpty ? 'Select Images (Max 6)' : '${selectedImages.length} image(s) selected'),
                    ),
                    if (selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedImages.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                Image.memory(selectedImages[index], width: 80, height: 80, fit: BoxFit.cover),
                                Positioned(top: 0, right: 0, child: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => selectedImages.removeAt(index)), style: IconButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(24, 24)))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            setState(() => isLoading = true);
                            try {
                               final docRef = await FirebaseFirestore.instance.collection('products').add({
                                 'name': nameCtrl.text,
                                 'description': descCtrl.text,
                                 'price': double.parse(priceCtrl.text),
                                 'stock': int.parse(stockCtrl.text),
                                 'minimumQuantity': int.parse(minQtyCtrl.text),
                                 'mrp': double.tryParse(mrpCtrl.text) ?? 0.0,
                                 'category': selectedCategory,
                                 'unit': selectedUnit,
                                 'isFeatured': isFeatured,
                                 'isHotDeal': (double.tryParse(mrpCtrl.text) ?? 0) > double.parse(priceCtrl.text),
                                 'isCustomerChoice': false, // sales based
                                 'salesCount': 0,
                                 'sellerId': 'admin', // Or current user? Admin panel implies admin.
                                 'createdAt': FieldValue.serverTimestamp(),
                                 'updatedAt': FieldValue.serverTimestamp(),
                               });
                               if (selectedImages.isNotEmpty) {
                                 final urls = await uploadImages(docRef.id);
                                 await docRef.update({
                                   'imageUrls': urls, // Standardized key
                                   'imageUrl': urls.first, // Main image for backward compat/simple access
                                 }); 
                               }
                               if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added successfully')));
                               }
                            } catch (e) {
                              setState(() => isLoading = false);
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                          child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add Product'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProductDialog(String productId, Map<String, dynamic> productData) {
      final formKey = GlobalKey<FormState>();
      final nameCtrl = TextEditingController(text: productData['name']);
      final descCtrl = TextEditingController(text: productData['description']);
      final priceCtrl = TextEditingController(text: productData['price'].toString());
      final mrpCtrl = TextEditingController(text: (productData['mrp'] ?? 0).toString());
      final stockCtrl = TextEditingController(text: productData['stock'].toString());
      final minQtyCtrl = TextEditingController(text: (productData['minimumQuantity'] ?? 1).toString());
      
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final categories = categoryProvider.categories.map((c) => c.name).toList();
      String selectedCategory = productData['category'] ?? (categories.isNotEmpty ? categories.first : '');
      if (categories.isNotEmpty && !categories.contains(selectedCategory)) {
        selectedCategory = categories.first;
      }
      
      String selectedUnit = productData['unit'] ?? 'Pic';
      bool isFeatured = productData['isFeatured'] ?? false;
      bool isHotDeal = productData['isHotDeal'] ?? false;
      bool isCustomerChoice = productData['isCustomerChoice'] ?? false;
      bool isLoading = false;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => Dialog(
            child: Container(
              width: 600,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Edit Product', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 16),
                      TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()), validator: (v) => v?.isNotEmpty == true ? null : 'Required'),
                       const SizedBox(height: 16),
                      TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 3),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                              controller: mrpCtrl,
                              decoration: const InputDecoration(labelText: 'MRP (Original Price)', border: OutlineInputBorder(), prefixText: '₹'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                final p = double.tryParse(priceCtrl.text) ?? 0;
                                final m = double.tryParse(val) ?? 0;
                                if (m > p && p > 0) {
                                   setState(() => isHotDeal = true);
                                }
                              }
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(
                              controller: priceCtrl,
                              decoration: const InputDecoration(labelText: 'Selling Price *', border: OutlineInputBorder(), prefixText: '₹'),
                              keyboardType: TextInputType.number,
                              validator: (v) => double.tryParse(v ?? '') != null ? null : 'Invalid',
                              onChanged: (val) {
                                final p = double.tryParse(val) ?? 0;
                                final m = double.tryParse(mrpCtrl.text) ?? 0;
                                if (m > p && p > 0) {
                                   setState(() => isHotDeal = true);
                                }
                              }
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stock *', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) => int.tryParse(v ?? '') != null ? null : 'Invalid')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                         controller: minQtyCtrl,
                         decoration: const InputDecoration(labelText: 'Minimum Quantity', border: OutlineInputBorder()),
                         keyboardType: TextInputType.number,
                         validator: (v) => (v?.isEmpty == true || int.tryParse(v!) == null || int.parse(v) < 1) ? 'Min 1' : null,
                      ),
                      const SizedBox(height: 16),
                      MediaQuery.of(context).size.width < 600
                      ? Column(
                          children: [
                            DropdownButtonFormField(
                              value: selectedCategory,
                              items: Provider.of<CategoryProvider>(context, listen: false).categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                              onChanged: (v) => setState(() => selectedCategory = v!),
                              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder())
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField(
                              value: selectedUnit,
                              items: ['Kg','Ltr','Pic','Pkt','Grm'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (v) => setState(() => selectedUnit = v!),
                              decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder())
                            ),
                          ],
                        )
                      : Row(
                        children: [
                          Expanded(child: DropdownButtonFormField(value: selectedCategory, items: Provider.of<CategoryProvider>(context, listen: false).categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(), onChanged: (v) => setState(() => selectedCategory = v!), decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()))),
                          const SizedBox(width: 16),
                          Expanded(child: DropdownButtonFormField(value: selectedUnit, items: ['Kg','Ltr','Pic','Pkt','Grm'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setState(() => selectedUnit = v!), decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(title: const Text('Featured Product'), value: isFeatured, onChanged: (v) => setState(() => isFeatured = v)),
                    const SizedBox(height: 16),
                        Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isLoading ? null : () async {
                              if (!formKey.currentState!.validate()) return;
                              setState(() => isLoading = true);
                              try {
                                await FirebaseFirestore.instance.collection('products').doc(productId).update({
                                  'name': nameCtrl.text,
                                  'description': descCtrl.text,
                                  'price': double.parse(priceCtrl.text),
                                  'stock': int.parse(stockCtrl.text),
                                  'minimumQuantity': int.parse(minQtyCtrl.text),
                                  'mrp': double.tryParse(mrpCtrl.text) ?? 0.0,
                                  'category': selectedCategory,
                                  'unit': selectedUnit,
                                  'isFeatured': isFeatured,
                                  'isHotDeal': (double.tryParse(mrpCtrl.text) ?? 0) > double.parse(priceCtrl.text),
                                  // isCustomerChoice not updated manually anymore
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated successfully')));
                                }
                              } catch (e) {
                                setState(() => isLoading = false);
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                            child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Changes'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  }

  Future<void> _bulkDeleteProducts() async {
      final count = _selectedProductIds.length;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete $count Product${count > 1 ? 's' : ''}?'),
          content: const Text('This action cannot be undone. All selected products will be permanently deleted.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleting $count product${count > 1 ? 's' : ''}...'), duration: const Duration(seconds: 2)));
          
          final batch = FirebaseFirestore.instance.batch();
          for (var id in _selectedProductIds) {
            batch.delete(FirebaseFirestore.instance.collection('products').doc(id));
          }
          await batch.commit();

          setState(() {
            _selectedProductIds.clear();
            _isProductSelectionMode = false;
          });
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count product${count > 1 ? 's' : ''} deleted successfully'), backgroundColor: Colors.green));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting products: $e'), backgroundColor: Colors.red));
        }
      }
  }

  void _showBulkEditProductsDialog() {
      final count = _selectedProductIds.length;
      String editType = 'price';
      String priceAction = 'add_percent';
      String stockAction = 'add';
      final priceCtrl = TextEditingController();
      final stockCtrl = TextEditingController();
      String? selectedCategory;
      bool? setFeatured;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => Dialog(
            child: Container(
              width: 600,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bulk Edit $count Product${count > 1 ? 's' : ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Divider(),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: editType,
                      decoration: const InputDecoration(labelText: 'What to Edit', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'price', child: Text('Price')),
                        DropdownMenuItem(value: 'stock', child: Text('Stock')),
                        DropdownMenuItem(value: 'category', child: Text('Category')),
                        DropdownMenuItem(value: 'featured', child: Text('Featured Status')),
                      ],
                      onChanged: (val) => setState(() => editType = val!),
                    ),
                    const SizedBox(height: 16),
                    if (editType == 'price') ...[
                      DropdownButtonFormField<String>(value: priceAction, items: const [DropdownMenuItem(value: 'add_percent', child: Text('Increase by %')), DropdownMenuItem(value: 'subtract_percent', child: Text('Decrease by %')), DropdownMenuItem(value: 'set_fixed', child: Text('Set to Fixed Value'))], onChanged: (v) => setState(() => priceAction = v!), decoration: const InputDecoration(labelText: 'Action', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextFormField(controller: priceCtrl, decoration: InputDecoration(labelText: priceAction == 'set_fixed' ? 'New Price' : 'Percentage', border: const OutlineInputBorder(), prefixText: priceAction == 'set_fixed' ? '₹' : '', suffixText: priceAction != 'set_fixed' ? '%' : ''), keyboardType: TextInputType.number),
                    ],
                    if (editType == 'stock') ...[
                       DropdownButtonFormField<String>(value: stockAction, items: const [DropdownMenuItem(value: 'add', child: Text('Add to Stock')), DropdownMenuItem(value: 'subtract', child: Text('Subtract from Stock')), DropdownMenuItem(value: 'set', child: Text('Set to Value'))], onChanged: (v) => setState(() => stockAction = v!), decoration: const InputDecoration(labelText: 'Action', border: OutlineInputBorder())),
                       const SizedBox(height: 16),
                       TextFormField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stock Value', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                    ],
                    if (editType == 'category') ...[
                       DropdownButtonFormField<String>(value: selectedCategory, items: ProductCategory.all.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => selectedCategory = v!), decoration: const InputDecoration(labelText: 'New Category', border: OutlineInputBorder())),
                    ],
                    if (editType == 'featured') ...[
                       DropdownButtonFormField<bool>(value: setFeatured, items: const [DropdownMenuItem(value: true, child: Text('Set as Featured')), DropdownMenuItem(value: false, child: Text('Remove from Featured'))], onChanged: (v) => setState(() => setFeatured = v), decoration: const InputDecoration(labelText: 'Featured Status', border: OutlineInputBorder())),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                              Navigator.pop(context);
                              try {
                                  final batch = FirebaseFirestore.instance.batch();
                                  for (var productId in _selectedProductIds) {
                                      final docRef = FirebaseFirestore.instance.collection('products').doc(productId);
                                      if (editType == 'price' && priceCtrl.text.isNotEmpty) {
                                          final val = double.tryParse(priceCtrl.text);
                                          if (val != null) {
                                              if (priceAction == 'set_fixed') {
                                                  batch.update(docRef, {'price': val});
                                              } else {
                                                  final doc = await docRef.get();
                                                  final current = (doc.data()?['price'] as num?)?.toDouble() ?? 0;
                                                  final newVal = priceAction == 'add_percent' ? current * (1 + val/100) : current * (1 - val/100);
                                                  batch.update(docRef, {'price': newVal});
                                              }
                                          }
                                      } else if (editType == 'stock' && stockCtrl.text.isNotEmpty) {
                                           final val = int.tryParse(stockCtrl.text);
                                           if (val != null) {
                                               if (stockAction == 'set') {
                                                   batch.update(docRef, {'stock': val});
                                               } else {
                                                   final doc = await docRef.get();
                                                   final current = (doc.data()?['stock'] as num?)?.toInt() ?? 0;
                                                   final newVal = stockAction == 'add' ? current + val : current - val;
                                                   batch.update(docRef, {'stock': newVal.clamp(0, 999999)});
                                               }
                                           }
                                      } else if (editType == 'category' && selectedCategory != null) {
                                          batch.update(docRef, {'category': selectedCategory});
                                      } else if (editType == 'featured' && setFeatured != null) {
                                          batch.update(docRef, {'isFeatured': setFeatured});
                                      }
                                  }
                                  await batch.commit();
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count products updated'), backgroundColor: Colors.green));
                                  setState(() {
                                      _selectedProductIds.clear();
                                      _isProductSelectionMode = false;
                                  });
                              } catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                              }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                          child: const Text('Apply Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}
