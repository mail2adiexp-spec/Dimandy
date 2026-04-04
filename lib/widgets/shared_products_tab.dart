import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/category_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/locations_data.dart'; // Import locations data
import 'edit_product_dialog.dart';

class SharedProductsTab extends StatefulWidget {
  final bool canManage;
  final String?
  sellerId; // If provided, limits to specific seller (e.g. for seller dashboard)
  final String?
  storeId; // If provided, limits to specific store (e.g. for store manager dashboard)
  final bool isPartnerView; // If true, shows purchasing prices and partner-specific UI
  
  const SharedProductsTab({
    Key? key,
    this.canManage = true,
    this.sellerId,
    this.storeId,
    this.isPartnerView = false,
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
  String _customerChoiceFilter =
      'All'; // All, CustomerChoice, NonCustomerChoice
  DateTime? _productStartDate;
  DateTime? _productEndDate;

  // Selection Mode
  bool _isProductSelectionMode = false;
  Set<String> _selectedProductIds = {};

  // Image Picker
  final ImagePicker _picker = ImagePicker();
  List<Uint8List> _selectedImages = [];
  final List<String> _availableStates =
      LocationsData.cities.map((e) => e.state).toSet().toList()..sort();

  late Stream<QuerySnapshot> _productsStream;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  @override
  void didUpdateWidget(SharedProductsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sellerId != oldWidget.sellerId ||
        widget.storeId != oldWidget.storeId) {
      _initializeStream();
    }
  }

  void _initializeStream() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Query query = FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true);

    if (widget.sellerId != null) {
      query = query.where('sellerId', isEqualTo: widget.sellerId);
    } else if (widget.storeId != null) {
      // Filter by Store ID (array-contains because storeIds is a list in product model)
      query = query.where('storeIds', arrayContains: widget.storeId);
    } else if (auth.isStateAdmin && auth.currentUser?.assignedState != null) {
      // Filter by state for State Admins
      // Note: This requires an index on 'state' and 'createdAt'
      query = query.where('state', isEqualTo: auth.currentUser!.assignedState);
    }

    _productsStream = query.snapshots();
  }

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
          _selectedImages = imageBytes;
        });
      } else if (images.length > 6) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 6 images allowed')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
      }
    }
  }

  Future<List<String>> uploadImages(String productId) async {
    List<String> imageUrls = [];
    for (int i = 0; i < _selectedImages.length; i++) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('products')
          .child(productId)
          .child('image_$i.jpg');
      await ref.putData(
        _selectedImages[i],
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      imageUrls.add(url);
    }
    return imageUrls;
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
          return Center(
            child: SelectionArea(
              child: SelectableText(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        var products = snapshot.data?.docs ?? [];

        // Client-side filtering
        products = _filterProducts(products);

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            // Header with Search, Filters, and Actions
            SliverToBoxAdapter(child: _buildHeader(products)),

            // Products Grid
            if (products.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 40,
                  ),
                  child: _buildEmptyState(),
                ),
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

  List<QueryDocumentSnapshot> _filterProducts(
    List<QueryDocumentSnapshot> products,
  ) {
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
        if (category == null ||
            !_selectedProductCategories.contains(category)) {
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
      if (_customerChoiceFilter == 'CustomerChoice' && !isCustomerChoice)
        return false;
      if (_customerChoiceFilter == 'NonCustomerChoice' && isCustomerChoice)
        return false;

      // Date Range
      if (_productStartDate != null || _productEndDate != null) {
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          if (_productStartDate != null &&
              createdAt.isBefore(_productStartDate!)) {
            return false;
          }
          if (_productEndDate != null &&
              createdAt.isAfter(
                _productEndDate!.add(const Duration(days: 1)),
              )) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  Widget _buildEmptyState() {
    bool isFiltered = _productSearchQuery.isNotEmpty || 
                      _selectedProductCategory != null || 
                      _minProductPrice != null || 
                      _maxProductPrice != null || 
                      _stockFilter != 'All' || 
                      _selectedProductCategories.isNotEmpty || 
                      _featuredFilter != 'All' || 
                      _hotDealFilter != 'All' || 
                      _customerChoiceFilter != 'All';

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No products found', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Try adjusting your filters or search query', style: TextStyle(color: Colors.grey)),
            if (isFiltered) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _productSearchQuery = '';
                    _selectedProductCategory = null;
                    _minProductPrice = null;
                    _maxProductPrice = null;
                    _stockFilter = 'All';
                    _selectedProductCategories.clear();
                    _featuredFilter = 'All';
                    _hotDealFilter = 'All';
                    _customerChoiceFilter = 'All';
                    _isProductSelectionMode = false;
                  });
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear All Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(List<QueryDocumentSnapshot> products) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Count and Actions
          // Top Row: Count and Actions
          MediaQuery.of(context).size.width < 600
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Products: ${products.length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!_isProductSelectionMode && widget.canManage)
                          OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _isProductSelectionMode = true),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        if (!_isProductSelectionMode && widget.canManage)
                          OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _isProductSelectionMode = true),
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
          if (_isProductSelectionMode && widget.canManage) ...[
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
                    value:
                        _selectedProductIds.length == products.length &&
                        products.isNotEmpty,
                    tristate: true,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedProductIds = products
                              .map((p) => p.id)
                              .toSet();
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
                    onPressed: _selectedProductIds.isEmpty
                        ? null
                        : _showBulkEditProductsDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Bulk Delete',
                    onPressed: _selectedProductIds.isEmpty
                        ? null
                        : _bulkDeleteProducts,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (val) =>
                          setState(() => _productSearchQuery = val),
                    ),
                     const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        hintText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      initialValue: _selectedProductCategory,
                      menuMaxHeight: 300,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ...Provider.of<CategoryProvider>(
                          context,
                        ).categories.map(
                          (c) => DropdownMenuItem(
                            value: c.name,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedProductCategory = val),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (val) =>
                            setState(() => _productSearchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          hintText: 'Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        initialValue: _selectedProductCategory,
                        menuMaxHeight: 300,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Categories'),
                          ),
                          ...Provider.of<CategoryProvider>(
                            context,
                          ).categories.map(
                            (c) => DropdownMenuItem(
                              value: c.name,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedProductCategory = val),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price Range
                    const Text(
                      'Price Range',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Min Price',
                              prefixText: '\u20B9',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(
                              () => _minProductPrice = double.tryParse(v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Max Price',
                              prefixText: '\u20B9',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(
                              () => _maxProductPrice = double.tryParse(v),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Stock
                    const Text(
                      'Stock Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _stockFilter,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(
                          value: 'Low',
                          child: Text('Low Stock (< 10)'),
                        ),
                        DropdownMenuItem(
                          value: 'Out',
                          child: Text('Out of Stock'),
                        ),
                        DropdownMenuItem(
                          value: 'InStock',
                          child: Text('In Stock'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _stockFilter = v!),
                    ),
                    const SizedBox(height: 16),
                    // Multi-Category
                    const Text(
                      'Categories (Multi-select)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: Provider.of<CategoryProvider>(context)
                          .categories
                          .map((cat) {
                            return FilterChip(
                              label: Text(cat.name),
                              selected: _selectedProductCategories.contains(
                                cat.name,
                              ),
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
                          })
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    // Featured
                    const Text(
                      'Featured Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _featuredFilter,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(
                          value: 'Featured',
                          child: Text('Featured Only'),
                        ),
                        DropdownMenuItem(
                          value: 'NonFeatured',
                          child: Text('Non-Featured'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _featuredFilter = v!),
                    ),
                    const SizedBox(height: 16),
                    // Hot Deal
                    const Text(
                      'Hot Deal Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _hotDealFilter,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(
                          value: 'HotDeal',
                          child: Text('Hot Deal Only'),
                        ),
                        DropdownMenuItem(
                          value: 'NonHotDeal',
                          child: Text('Non-Hot Deal'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _hotDealFilter = v!),
                    ),
                    const SizedBox(height: 16),
                    // Customer Choice
                    const Text(
                      'Customer Choice Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _customerChoiceFilter,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(
                          value: 'CustomerChoice',
                          child: Text('Customer Choice Only'),
                        ),
                        DropdownMenuItem(
                          value: 'NonCustomerChoice',
                          child: Text('Non-Customer Choice'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _customerChoiceFilter = v!),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
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
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        100,
      ), // Increased to 100 bottom padding
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: MediaQuery.of(context).size.width < 600 ? 0.48 : 0.7, // Taller cards on mobile (2 cols)
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final product = products[index];
          final data = product.data() as Map<String, dynamic>;

          // Robust image extraction
          String? imageUrl = data['imageUrl'] as String?;
          if (imageUrl == null || imageUrl.isEmpty) {
            final List<dynamic> imagesList =
                (data['imageUrls'] as List<dynamic>?) ??
                (data['images'] as List<dynamic>?) ??
                [];

            if (imagesList.isNotEmpty) {
              imageUrl = imagesList.first.toString();
            }
          }

          return Stack(
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side:
                      _isProductSelectionMode &&
                          _selectedProductIds.contains(product.id)
                      ? const BorderSide(color: Colors.blue, width: 3)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () {
                    if (_isProductSelectionMode) {
                      setState(() {
                        if (_selectedProductIds.contains(product.id)) {
                          _selectedProductIds.remove(product.id);
                        } else {
                          _selectedProductIds.add(product.id);
                        }
                      });
                    } else if (widget.canManage) {
                      showDialog(
                        context: context,
                        builder: (context) => EditProductDialog(
                          productId: product.id,
                          productData: data,
                        ),
                      );
                    }
                  },
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
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: imageUrl != null
                              ? ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.image_not_supported,
                                      size: 40,
                                    ),
                                  ),
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
                            Text(
                              data['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat.currency(
                                locale: 'en_IN',
                                symbol: '\u20B9',
                              ).format(data['price'] ?? 0),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (widget.isPartnerView) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Purchase: \u20B9${data['basePrice'] ?? 0}',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  data['isFeatured'] == true
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Stock: ${data['stock'] ?? 0} ${data['unit'] ?? ''}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
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
              if (!_isProductSelectionMode && widget.canManage)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.blue, size: 16),
                      onPressed: () => _showQuickAddStockDialog(product.id, data),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Quick Add Stock (Purchase)',
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (value) {
                        if (value == 'edit') {
                          showDialog(
                            context: context,
                            builder: (context) => EditProductDialog(
                              productId: product.id,
                              productData: data,
                            ),
                          );
                        } else if (value == 'delete') {
                          _deleteProduct(product.id, data['name'] ?? 'Product');
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Edit Details'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }, childCount: products.length),
      ),
    );
  }

  void _showQuickAddStockDialog(String productId, Map<String, dynamic> data) {
    final TextEditingController addQtyController = TextEditingController();
    final TextEditingController newBasePriceController = TextEditingController(text: (data['basePrice'] ?? 0).toString());
    int currentStock = (data['stock'] as num?)?.toInt() ?? 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Stock: ${data['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Stock: $currentStock ${data['unit'] ?? 'Pic'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 16),
            TextField(
              controller: addQtyController,
              decoration: const InputDecoration(
                labelText: 'New Stock Quantity (to add)',
                hintText: 'e.g. 50',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add_box),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newBasePriceController,
              decoration: const InputDecoration(
                labelText: 'New Purchase Price per unit',
                prefixText: '\u20B9 ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_cart),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              int addQty = int.tryParse(addQtyController.text) ?? 0;
              double newBasePrice = double.tryParse(newBasePriceController.text) ?? (data['basePrice'] ?? 0).toDouble();
              
              if (addQty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid quantity')));
                return;
              }

              await FirebaseFirestore.instance.collection('products').doc(productId).update({
                'stock': currentStock + addQty,
                'basePrice': newBasePrice,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $addQty ${data['unit'] ?? 'items'} successfully!')));
              }
            },
            child: const Text('Add Stock Now'),
          ),
        ],
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .delete();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully')),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
      }
    }
  }

  void _showAddProductDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: '\u2022 ');
    final basePriceCtrl = TextEditingController();
    final mrpCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final minQtyCtrl = TextEditingController(text: '1');
    final maxQtyCtrl = TextEditingController(text: '0');
    final adminProfitPercentageCtrl = TextEditingController(); // Added commission controller

    String selectedCategory = Provider.of<CategoryProvider>(context, listen: false).categories.isNotEmpty
        ? Provider.of<CategoryProvider>(context, listen: false).categories.first.name
        : '';
    String selectedUnit = 'Pic';
    bool isFeatured = false;
    bool isLoading = false;
    _selectedImages = [];
    final auth = Provider.of<AuthProvider>(context, listen: false);
    List<String> selectedStoreIds = widget.storeId != null ? [widget.storeId!] : [];
    String? selectedState = widget.storeId != null 
        ? auth.currentUser?.storeId == widget.storeId ? auth.currentUser?.state : null 
        : auth.currentUser?.state;

    Future<void> pickImages(StateSetter setState) async {
      try {
        final List<XFile> images = await ImagePicker().pickMultiImage();
        if (images.isNotEmpty) {
          final List<Uint8List> imageBytes = [];
          for (var image in images.take(6 - _selectedImages.length)) {
            final bytes = await image.readAsBytes();
            imageBytes.add(bytes);
          }
          setState(() {
            _selectedImages.addAll(imageBytes);
          });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
      }
    }

    Future<List<String>> uploadImages(String productId) async {
      List<String> urls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final ref = FirebaseStorage.instance.ref().child('products').child(productId).child('img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        await ref.putData(_selectedImages[i], SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        urls.add(url);
      }
      return urls;
    }

    String? dialogError;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            child: Container(
              padding: const EdgeInsets.all(24),
              width: MediaQuery.of(context).size.width > 700 ? 700 : double.maxFinite,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dialogError != null) 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                            child: Row(children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold))),
                            ]),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Add New Product', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 16),
                      TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()), validator: (v) => (v?.isEmpty == true || v!.length < 3) ? 'Required' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 3),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: TextFormField(controller: basePriceCtrl, decoration: const InputDecoration(labelText: 'Base Price', border: OutlineInputBorder(), prefixText: '\u20B9'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: mrpCtrl, decoration: const InputDecoration(labelText: 'MRP', border: OutlineInputBorder(), prefixText: '\u20B9'), keyboardType: TextInputType.number)),
                      ]),
                      const SizedBox(height: 16),
                      TextFormField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Selling Price *', border: OutlineInputBorder(), prefixText: '\u20B9'), keyboardType: TextInputType.number, validator: (v) => (v?.isEmpty == true) ? 'Required' : null),
                      const SizedBox(height: 12),
                      ListenableBuilder(
                        listenable: Listenable.merge([priceCtrl, mrpCtrl]),
                        builder: (context, _) {
                          final p = double.tryParse(priceCtrl.text) ?? 0;
                          final m = double.tryParse(mrpCtrl.text) ?? 0;
                          if (m <= p || m <= 0) return const SizedBox.shrink();
                          return Text('Discount: ${(((m - p) / m) * 100).toStringAsFixed(1)}% OFF', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
                        }
                      ),
                      const Divider(),
                      DropdownButtonFormField<String>(value: selectedUnit, decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()), items: ['Kg','Ltr','Pic','Pkt','Grm','Box'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setState(() => selectedUnit = v!)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: TextFormField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stock *', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) => (v?.isEmpty == true) ? 'Required' : null)),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: minQtyCtrl, decoration: const InputDecoration(labelText: 'Min Qty', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                      ]),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(value: selectedCategory, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()), items: Provider.of<CategoryProvider>(context, listen: false).categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(), onChanged: (v) => setState(() => selectedCategory = v!)),
                      const SizedBox(height: 16),
                      SwitchListTile(title: const Text('Featured Product'), value: isFeatured, onChanged: (v) => setState(() => isFeatured = v)),
                      const SizedBox(height: 16),
                      // Admin Commission (Only for Admin/Super Admin)
                      if (auth.hasAdminAccess) ...[
                        TextFormField(
                          controller: adminProfitPercentageCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Admin Profit Sharing (%) [Admin Only]',
                            border: OutlineInputBorder(),
                            suffixText: '%',
                            helperText: 'Leave empty for 0% (Seller gets full profit)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 16),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => pickImages(setState), 
                        icon: const Icon(Icons.image), 
                        label: Text(_selectedImages.isEmpty ? 'Select Images' : '${_selectedImages.length} images')
                      ),
                      if (_selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  Image.memory(_selectedImages[index], width: 80, height: 80, fit: BoxFit.cover),
                                  Positioned(
                                    top: 0, right: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      onPressed: () => setState(() => _selectedImages.removeAt(index)),
                                      style: IconButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(24, 24)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            setState(() => isLoading = true);
                            try {
                              final sp = double.parse(priceCtrl.text);
                              final m = double.tryParse(mrpCtrl.text) ?? sp;
                              final docRef = await FirebaseFirestore.instance.collection('products').add({
                                'name': nameCtrl.text,
                                'description': descCtrl.text,
                                'price': sp,
                                'mrp': m,
                                'stock': int.parse(stockCtrl.text),
                                'category': selectedCategory,
                                'unit': selectedUnit,
                                'isFeatured': isFeatured,
                                'isHotDeal': m > sp,
                                'sellerId': auth.isAdmin ? 'admin' : auth.currentUser?.uid ?? 'partner',
                                'storeIds': selectedStoreIds,
                                'state': selectedState,
                                'adminProfitPercentage': adminProfitPercentageCtrl.text.isNotEmpty 
                                    ? double.tryParse(adminProfitPercentageCtrl.text) 
                                    : null, // If empty, defaults to null (handled as 0% in calculations)
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              if (_selectedImages.isNotEmpty) {
                                final urls = await uploadImages(docRef.id);
                                await docRef.update({'imageUrls': urls, 'imageUrl': urls.first});
                              }
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                              }
                            } catch (e) {
                              setState(() {
                                isLoading = false;
                                dialogError = e.toString().toLowerCase().contains('permission') ? "⚠️ Permission Denied: You cannot add products." : "Error: $e";
                              });
                            }
                          },
                          child: isLoading ? const SizedBox(width:20,height:20,child:CircularProgressIndicator()) : const Text('Add Product'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditProductDialog(String productId, Map<String, dynamic> productData) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: productData['name']);
    final descCtrl = TextEditingController(text: productData['description']);
    final priceCtrl = TextEditingController(text: productData['price'].toString());
    final basePriceCtrl = TextEditingController(text: (productData['basePrice'] ?? 0.0).toString());
    final mrpCtrl = TextEditingController(text: (productData['mrp'] ?? 0).toString());
    final stockCtrl = TextEditingController(text: productData['stock'].toString());
    final minQtyCtrl = TextEditingController(text: (productData['minimumQuantity'] ?? 1).toString());

    String selectedCategory = productData['category'] ?? '';
    String selectedUnit = productData['unit'] ?? 'Pic';
    bool isFeatured = productData['isFeatured'] ?? false;
    bool isLoading = false;
    List<String> existingImageUrls = List<String>.from(productData['imageUrls'] ?? []);
    List<Uint8List> newImages = [];
    final auth = Provider.of<AuthProvider>(context, listen: false);
    List<String> selectedStoreIds = List<String>.from(productData['storeIds'] ?? []);
    String? selectedState = productData['state'];

    Future<void> pickImages(StateSetter setState) async {
      try {
        final List<XFile> images = await ImagePicker().pickMultiImage();
        if (images.isNotEmpty) {
          final List<Uint8List> imageBytes = [];
          for (var image in images.take(6 - existingImageUrls.length - newImages.length)) {
            final bytes = await image.readAsBytes();
            imageBytes.add(bytes);
          }
          setState(() {
            newImages.addAll(imageBytes);
          });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
      }
    }

    Future<List<String>> uploadImages(String productId) async {
      List<String> urls = List.from(existingImageUrls);
      for (int i = 0; i < newImages.length; i++) {
        final ref = FirebaseStorage.instance.ref().child('products').child(productId).child('upd_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        await ref.putData(newImages[i], SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        urls.add(url);
      }
      return urls;
    }

    String? dialogError;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            child: Container(
              padding: const EdgeInsets.all(24),
              width: MediaQuery.of(context).size.width > 700 ? 700 : double.maxFinite,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dialogError != null) 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                            child: Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Edit Product', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ]),
                      const Divider(),
                      TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Desc', border: OutlineInputBorder()), maxLines: 2),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: TextFormField(controller: mrpCtrl, decoration: const InputDecoration(labelText: 'MRP', border: OutlineInputBorder()))),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()))),
                      ]),
                      const SizedBox(height: 16),
                      ListenableBuilder(
                        listenable: Listenable.merge([priceCtrl, mrpCtrl]),
                        builder: (context, _) {
                          final p = double.tryParse(priceCtrl.text) ?? 0;
                          final m = double.tryParse(mrpCtrl.text) ?? 0;
                          if (m <= p || m <= 0) return const SizedBox.shrink();
                          return Text('Discount: ${(((m - p) / m) * 100).toStringAsFixed(1)}% OFF', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
                        }
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => pickImages(setState),
                        icon: const Icon(Icons.image),
                        label: Text('Add Images (${existingImageUrls.length + newImages.length}/6)')
                      ),
                      if (existingImageUrls.isNotEmpty || newImages.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (int i = 0; i < existingImageUrls.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Stack(
                                    children: [
                                      Image.network(existingImageUrls[i], width: 80, height: 80, fit: BoxFit.cover),
                                      Positioned(
                                        top: 0, right: 0,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, size: 16),
                                          onPressed: () => setState(() => existingImageUrls.removeAt(i)),
                                          style: IconButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(24, 24)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              for (int i = 0; i < newImages.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Stack(
                                    children: [
                                      Image.memory(newImages[i], width: 80, height: 80, fit: BoxFit.cover),
                                      Positioned(
                                        top: 0, right: 0,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, size: 16),
                                          onPressed: () => setState(() => newImages.removeAt(i)),
                                          style: IconButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(24, 24)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            setState(() => isLoading = true);
                            try {
                              final sp = double.parse(priceCtrl.text);
                              final m = double.tryParse(mrpCtrl.text) ?? sp;
                              final updatedUrls = await uploadImages(productId);
                              await FirebaseFirestore.instance.collection('products').doc(productId).update({
                                'name': nameCtrl.text,
                                'description': descCtrl.text,
                                'price': sp,
                                'mrp': m,
                                'stock': int.parse(stockCtrl.text),
                                'isHotDeal': m > sp,
                                'updatedAt': FieldValue.serverTimestamp(),
                                'imageUrls': updatedUrls,
                                'imageUrl': updatedUrls.isNotEmpty ? updatedUrls.first : null,
                              });
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                              }
                            } catch (e) {
                              setState(() {
                                isLoading = false;
                                dialogError = e.toString().toLowerCase().contains('permission') ? "⚠️ Permission Denied: You cannot edit this product." : "Error: $e";
                              });
                            }
                          },
                          child: isLoading ? const SizedBox(width:20,height:20,child:CircularProgressIndicator()) : const Text('Save Changes'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _bulkDeleteProducts() async {
    final count = _selectedProductIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count Product${count > 1 ? 's' : ''}?'),
        content: const Text(
          'This action cannot be undone. All selected products will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleting $count product${count > 1 ? 's' : ''}...'),
            duration: const Duration(seconds: 2),
          ),
        );

      try {
        final batch = FirebaseFirestore.instance.batch();
        for (var id in _selectedProductIds) {
          batch.delete(
            FirebaseFirestore.instance.collection('products').doc(id),
          );
        }
        await batch.commit();

        setState(() {
          _selectedProductIds.clear();
          _isProductSelectionMode = false;
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$count product${count > 1 ? 's' : ''} deleted successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting products: $e'),
              backgroundColor: Colors.red,
            ),
          );
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
                  Text(
                    'Bulk Edit $count Product${count > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: editType,
                    decoration: const InputDecoration(
                      labelText: 'What to Edit',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'price', child: Text('Price')),
                      DropdownMenuItem(value: 'stock', child: Text('Stock')),
                      DropdownMenuItem(
                        value: 'category',
                        child: Text('Category'),
                      ),
                      DropdownMenuItem(
                        value: 'featured',
                        child: Text('Featured Status'),
                      ),
                    ],
                    onChanged: (val) => setState(() => editType = val!),
                  ),
                  const SizedBox(height: 16),
                  if (editType == 'price') ...[
                    DropdownButtonFormField<String>(
                      initialValue: priceAction,
                      items: const [
                        DropdownMenuItem(
                          value: 'add_percent',
                          child: Text('Increase by %'),
                        ),
                        DropdownMenuItem(
                          value: 'subtract_percent',
                          child: Text('Decrease by %'),
                        ),
                        DropdownMenuItem(
                          value: 'set_fixed',
                          child: Text('Set to Fixed Value'),
                        ),
                      ],
                      onChanged: (v) => setState(() => priceAction = v!),
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceCtrl,
                      decoration: InputDecoration(
                        labelText: priceAction == 'set_fixed'
                            ? 'New Price'
                            : 'Percentage',
                        border: const OutlineInputBorder(),
                        prefixText: priceAction == 'set_fixed' ? '\u20B9' : '',
                        suffixText: priceAction != 'set_fixed' ? '%' : '',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  if (editType == 'stock') ...[
                    DropdownButtonFormField<String>(
                      initialValue: stockAction,
                      items: const [
                        DropdownMenuItem(
                          value: 'add',
                          child: Text('Add to Stock'),
                        ),
                        DropdownMenuItem(
                          value: 'subtract',
                          child: Text('Subtract from Stock'),
                        ),
                        DropdownMenuItem(
                          value: 'set',
                          child: Text('Set to Value'),
                        ),
                      ],
                      onChanged: (v) => setState(() => stockAction = v!),
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: stockCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Stock Value',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  if (editType == 'category') ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      items: ProductCategory.all
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedCategory = v!),
                      decoration: const InputDecoration(
                        labelText: 'New Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (editType == 'featured') ...[
                    DropdownButtonFormField<bool>(
                      initialValue: setFeatured,
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Text('Set as Featured'),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text('Remove from Featured'),
                        ),
                      ],
                      onChanged: (v) => setState(() => setFeatured = v),
                      decoration: const InputDecoration(
                        labelText: 'Featured Status',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            final batch = FirebaseFirestore.instance.batch();
                            for (var productId in _selectedProductIds) {
                              final docRef = FirebaseFirestore.instance
                                  .collection('products')
                                  .doc(productId);
                              if (editType == 'price' &&
                                  priceCtrl.text.isNotEmpty) {
                                final val = double.tryParse(priceCtrl.text);
                                if (val != null) {
                                  if (priceAction == 'set_fixed') {
                                    batch.update(docRef, {'price': val});
                                  } else {
                                    final doc = await docRef.get();
                                    final current =
                                        (doc.data()?['price'] as num?)
                                            ?.toDouble() ??
                                        0;
                                    final newVal = priceAction == 'add_percent'
                                        ? current * (1 + val / 100)
                                        : current * (1 - val / 100);
                                    batch.update(docRef, {'price': newVal});
                                  }
                                }
                              } else if (editType == 'stock' &&
                                  stockCtrl.text.isNotEmpty) {
                                final val = int.tryParse(stockCtrl.text);
                                if (val != null) {
                                  if (stockAction == 'set') {
                                    batch.update(docRef, {'stock': val});
                                  } else {
                                    final doc = await docRef.get();
                                    final current =
                                        (doc.data()?['stock'] as num?)
                                            ?.toInt() ??
                                        0;
                                    final newVal = stockAction == 'add'
                                        ? current + val
                                        : current - val;
                                    batch.update(docRef, {
                                      'stock': newVal.clamp(0, 999999),
                                    });
                                  }
                                }
                              } else if (editType == 'category' &&
                                  selectedCategory != null) {
                                batch.update(docRef, {
                                  'category': selectedCategory,
                                });
                              } else if (editType == 'featured' &&
                                  setFeatured != null) {
                                batch.update(docRef, {
                                  'isFeatured': setFeatured,
                                });
                              }
                            }
                            await batch.commit();
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$count products updated'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            setState(() {
                              _selectedProductIds.clear();
                              _isProductSelectionMode = false;
                            });
                          } catch (e) {
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
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
