import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'seller_stock_report_screen.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../providers/auth_provider.dart';
import '../models/product_model.dart';
import '../widgets/seller_orders_dialog.dart';
import '../widgets/edit_product_dialog.dart';
import '../providers/category_provider.dart';
import 'seller_analytics_screen.dart';
import 'seller_wallet_screen.dart';
import '../widgets/notifications_dialog.dart';



class SellerDashboardScreen extends StatefulWidget {
  static const routeName = '/seller-dashboard';
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  Stream<QuerySnapshot>? _productsStream;
  Stream<QuerySnapshot>? _lowStockStream;
  Stream<QuerySnapshot>? _recentActivityStream;
  Stream<QuerySnapshot>? _ordersStream;
  Stream<QuerySnapshot>? _deliveredOrdersStream;
  Stream<QuerySnapshot>? _manageProductsStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthProvider>(context).currentUser;
    if (user != null && _productsStream == null) {
      _initializeStreams(user.uid);
    }
  }

  void _initializeStreams(String userId) {
    _productsStream = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: userId)
        .snapshots();

    _lowStockStream = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: userId)
        .where('stock', isLessThan: 10)
        .snapshots();

    _recentActivityStream = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('orderDate', descending: true)
        .limit(5)
        .snapshots();

    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .snapshots();

    _deliveredOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'delivered')
        .snapshots();

    _manageProductsStream = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
  
  // Add Product Dialog
  void _showAddProductDialog(BuildContext context, AppUser user) {
    // CRITICAL: Capture the ScaffoldMessenger BEFORE showing dialog
    // This ensures error messages appear on top of the dialog, not behind it
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: '\u2022 ');
    final priceCtrl = TextEditingController();
    final basePriceCtrl = TextEditingController(); // Added Base Price
    final mrpCtrl = TextEditingController(); // Added MRP
    final stockCtrl = TextEditingController();
    final minQtyCtrl = TextEditingController(text: '1');
    
    // Use CategoryProvider for dynamic categories
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final categories = categoryProvider.categories.map((c) => c.name).toList();
    
    String selectedCategory = categories.isNotEmpty 
        ? (categories.contains('Daily Needs') ? 'Daily Needs' : categories.first) 
        : 'Daily Needs';
    
    String selectedUnit = 'Pic';
    bool isFeatured = false;
    bool isHotDeal = false; // Auto-calculated
    bool isLoading = false;
    List<Uint8List> selectedImages = [];
    final ImagePicker picker = ImagePicker();

    Future<void> pickImages(StateSetter setState) async {
      try {
        final List<XFile> images = await picker.pickMultiImage();
        if (images.isNotEmpty) {
           if (images.length > 6) {
             scaffoldMessenger.showSnackBar(
               const SnackBar(
                 content: Text('Max 6 images allowed'),
                 behavior: SnackBarBehavior.floating,
               ),
             );
             return;
           }
          final List<Uint8List> imageBytes = [];
          for (var image in images) {
            final bytes = await image.readAsBytes();
            imageBytes.add(bytes);
          }
          setState(() {
            selectedImages = imageBytes;
          });
        }
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    Future<List<String>> uploadImages(String productId) async {
      final List<String> imageUrls = [];
      for (int i = 0; i < selectedImages.length; i++) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('products')
              .child(productId)
              .child('image_$i.jpg');
          await ref.putData(selectedImages[i]);
          final url = await ref.getDownloadURL();
          imageUrls.add(url);
        } catch (e) {
          print('Error uploading image $i: $e');
          
          // Create user-friendly error message
          String errorMessage = 'Failed to upload image ${i + 1}';
          
          // Check for permission errors
          if (e.toString().contains('unauthorized') || 
              e.toString().contains('permission') ||
              e.toString().contains('403')) {
            errorMessage = '⚠️ Permission Denied: Please contact admin to verify your seller account role is set correctly';
          } else if (e.toString().contains('network')) {
            errorMessage = '🌐 Network Error: Please check your internet connection';
          }
          
          // Throw exception with user-friendly message
          // This will be caught in the main try-catch and shown after dialog closes
          throw Exception(errorMessage);
        }
      }
      return imageUrls;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
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
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()),
                      validator: (v) => (v?.isEmpty == true || v!.length < 3) ? 'Required, min 3 chars' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      maxLines: 3,
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
                    const SizedBox(height: 16),
                    
                    // Prices and Stock Row
                    // Base Price and MRP
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: basePriceCtrl,
                            decoration: const InputDecoration(labelText: 'Base Price (Buying) *', border: OutlineInputBorder(), prefixText: '₹'),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v?.isEmpty == true || double.tryParse(v!) == null) ? 'Invalid' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: mrpCtrl,
                            decoration: const InputDecoration(labelText: 'MRP (Original)', border: OutlineInputBorder(), prefixText: '₹'),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                                final p = double.tryParse(priceCtrl.text) ?? 0;
                                final m = double.tryParse(val) ?? 0;
                                if (m > p && p > 0) setState(() => isHotDeal = true);
                            }
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Selling Price and Stock
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            decoration: const InputDecoration(labelText: 'Selling Price *', border: OutlineInputBorder(), prefixText: '₹'),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v?.isEmpty == true || double.tryParse(v!) == null) ? 'Invalid' : null,
                            onChanged: (val) {
                                setState(() {
                                  final p = double.tryParse(val) ?? 0;
                                  final m = double.tryParse(mrpCtrl.text) ?? 0;
                                  isHotDeal = (m > p && p > 0);
                                });
                            }
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: stockCtrl,
                            decoration: const InputDecoration(labelText: 'Stock *', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v?.isEmpty == true || int.tryParse(v!) == null) ? 'Invalid' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Platform Fee & Listing Price Preview
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('app_settings').doc('general').get(),
                      builder: (context, snapshot) {
                        double platformFeePercent = 0.05; // Default 5%
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          platformFeePercent = (data['sellerPlatformFeePercentage'] as num?)?.toDouble() ?? 
                                             (data['platformFeePercentage'] as num?)?.toDouble() ?? 0.0;
                          platformFeePercent = platformFeePercent / 100; // Convert to decimal (e.g. 5 -> 0.05)
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final price = double.tryParse(priceCtrl.text) ?? 0;
                                    final platformFee = price * platformFeePercent;
                                    final listingPrice = price + platformFee;
                                    
                                    return Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(text: 'Platform Fee (${(platformFeePercent * 100).toStringAsFixed(0)}%): '),
                                          TextSpan(
                                            text: '₹${platformFee.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                          ),
                                          const TextSpan(text: '  |  Listing Price: '),
                                          TextSpan(
                                            text: '₹${listingPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                          ),
                                        ],
                                        style: TextStyle(color: Colors.blue[900], fontSize: 13),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    TextFormField(
                       controller: minQtyCtrl,
                       decoration: const InputDecoration(labelText: 'Minimum Quantity', border: OutlineInputBorder()),
                       keyboardType: TextInputType.number,
                       validator: (v) => (v?.isEmpty == true || int.tryParse(v!) == null || int.parse(v) < 1) ? 'Min 1' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Category and Unit
                    MediaQuery.of(context).size.width < 600
                    ? Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => selectedCategory = v!),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedUnit,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                            items: ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (v) => setState(() => selectedUnit = v!),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCategory,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setState(() => selectedCategory = v!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedUnit,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                              items: ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (v) => setState(() => selectedUnit = v!),
                            ),
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 16),
                    // SwitchListTile for Featured removed as per user request
                    
                    // Image Picker
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(selectedImages[index], width: 80, height: 80, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 0, 
                                  right: 0, 
                                  child: InkWell(
                                    onTap: () => setState(() => selectedImages.removeAt(index)),
                                    child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white))
                                  )
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    
                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  if (selectedImages.isEmpty) {
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Please add at least one image'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  setState(() => isLoading = true);

                                  try {
                                    // Create product ID
                                    final productId = FirebaseFirestore.instance.collection('products').doc().id;
                                    
                                    // Upload images using captured ScaffoldMessenger
                                    final imageUrls = await uploadImages(productId);

                                    final mrp = double.tryParse(mrpCtrl.text) ?? 0.0;
                                    final price = double.parse(priceCtrl.text);

                                    // Create product document
                                    await FirebaseFirestore.instance.collection('products').doc(productId).set({
                                      'id': productId,
                                      'sellerId': user.uid,
                                      'name': nameCtrl.text.trim(),
                                      'description': descCtrl.text.trim(),
                                      'price': price,
                                      'basePrice': double.tryParse(basePriceCtrl.text) ?? 0.0,
                                      'mrp': mrp,
                                      'mrp': mrp,
                                      'stock': int.parse(stockCtrl.text),
                                      'minimumQuantity': int.parse(minQtyCtrl.text),
                                      'category': selectedCategory,
                                      'unit': selectedUnit,
                                      'imageUrl': imageUrls.first,
                                      'category': selectedCategory,
                                      'unit': selectedUnit,
                                      'imageUrl': imageUrls.first,
                                      'imageUrls': imageUrls,
                                      'isFeatured': false, // Sellers cannot feature their own products
                                      'isHotDeal': mrp > price,
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'rating': 0.0,
                                      'reviewCount': 0,
                                      'salesCount': 0,
                                    });

                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('✅ Product added successfully!'),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    // CRITICAL: Close dialog FIRST, then show error
                                    // This ensures error message is visible to the user
                                    if (context.mounted) {
                                      Navigator.pop(ctx); // Close the dialog
                                    }
                                    
                                    // Extract the error message
                                    String errorMsg = e.toString();
                                    if (errorMsg.startsWith('Exception: ')) {
                                      errorMsg = errorMsg.substring(11); // Remove "Exception: " prefix
                                    }
                                    
                                    // Show error after dialog is closed
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(errorMsg),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 6),
                                        action: SnackBarAction(
                                          label: 'Dismiss',
                                          textColor: Colors.white,
                                          onPressed: () {},
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => isLoading = false);
                                    }
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Add Product'),
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

  // Manage Products Dialog
  void _showManageProductsDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 900,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Products',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _manageProductsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final products = snapshot.data?.docs ?? [];

                    if (products.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_outlined, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text(
                              'No products yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showAddProductDialog(context, user);
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Your First Product'),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.0, // Square tiles for images
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      padding: const EdgeInsets.all(4),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final productData = products[index].data() as Map<String, dynamic>;
                        final productId = products[index].id;
                        final name = productData['name'] ?? 'Unknown';
                        final price = (productData['price'] as num?)?.toDouble() ?? 0;
                        final mrp = (productData['mrp'] as num?)?.toDouble() ?? 0;
                        final stock = (productData['stock'] as num?)?.toInt() ?? 0;
                        final imageUrl = productData['imageUrl'] as String?;
                        final isListed = productData['isListed'] ?? true; // Default to true

                        return Card(
                          elevation: 2,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 16)),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       if (imageUrl != null)
                                          Center(
                                            child: SizedBox(
                                              height: 100,
                                              width: 100,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(imageUrl, fit: BoxFit.cover),
                                              ),
                                            ),
                                          ),
                                       const SizedBox(height: 16),
                                       Text('Price: ₹${price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                       if (mrp > price)
                                         Text('MRP: ₹${mrp.toStringAsFixed(0)}', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                                       const SizedBox(height: 4),
                                       Text(
                                         'Stock: $stock', 
                                         style: TextStyle(
                                           color: stock > 0 ? Colors.green : Colors.red,
                                           fontWeight: FontWeight.bold
                                         )
                                       ),
                                       const SizedBox(height: 4),
                                       Row(
                                         children: [
                                           Text('Status: ', style: TextStyle(color: Colors.grey[700])),
                                           Text(
                                             isListed ? 'Listed' : 'Unlisted',
                                             style: TextStyle(
                                               color: isListed ? Colors.green : Colors.orange,
                                               fontWeight: FontWeight.bold,
                                             ),
                                           ),
                                         ],
                                       ),
                                    ],
                                  ),
                                  actions: [
                                     // Unlist/List Button
                                     TextButton.icon(
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .collection('products')
                                              .doc(productId)
                                              .update({'isListed': !isListed});
                                          if (context.mounted) Navigator.pop(ctx);
                                        },
                                        icon: Icon(
                                          isListed ? Icons.visibility_off : Icons.visibility,
                                          color: isListed ? Colors.orange : Colors.green
                                        ),
                                        label: Text(
                                          isListed ? 'Unlist' : 'List',
                                          style: TextStyle(color: isListed ? Colors.orange : Colors.green)
                                        ),
                                     ),
                                     TextButton.icon(
                                       onPressed: () async {
                                           final confirm = await showDialog<bool>(
                                             context: context,
                                             builder: (dialogCtx) => AlertDialog(
                                               title: const Text('Delete'),
                                               content: const Text('Delete this product?'),
                                               actions: [
                                                 TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('No')),
                                                 TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Yes')),
                                               ],
                                             ),
                                           );
                                           if (confirm == true) {
                                              await FirebaseFirestore.instance.collection('products').doc(productId).delete();
                                              if (context.mounted) Navigator.pop(ctx); // Close details dialog
                                           }
                                       },
                                       icon: const Icon(Icons.delete, color: Colors.red),
                                       label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                     ),
                                     ElevatedButton.icon(
                                       onPressed: () {
                                          Navigator.pop(ctx); // Close details dialog
                                          showDialog(
                                            context: context,
                                            builder: (context) => EditProductDialog(
                                              productId: productId,
                                              productData: productData,
                                            ),
                                          );
                                       },
                                       icon: const Icon(Icons.edit, size: 16),
                                       label: const Text('Edit'),
                                     ),
                                  ],
                                ),
                              );
                            },
                            child: Stack(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: imageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported, color: Colors.grey),
                                          ),
                                        )
                                      : const Icon(Icons.inventory_2, color: Colors.grey),
                                ),
                                if (!isListed)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.visibility_off, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // View Orders Dialog
  void _showViewOrdersDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SellerOrdersDialog(user: user),
      ),
    );
  }

  void _showInventoryOverviewDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Inventory Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              FutureBuilder<List<dynamic>>(
                future: Future.wait([
                  FirebaseFirestore.instance.collection('products').where('sellerId', isEqualTo: user.uid).get(),
                  FirebaseFirestore.instance.collection('orders').get(),
                ]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
                  }
                  
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final productsDocs = (snapshot.data![0] as QuerySnapshot).docs;
                  final ordersDocs = (snapshot.data![1] as QuerySnapshot).docs;

                  // 1. Total Products
                  final totalProducts = productsDocs.length;
                  
                  // 2. Inventory Valuation (Unsold Stock Value)
                  double inventoryValuation = 0;
                  for (var doc in productsDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final price = (data['price'] as num?)?.toDouble() ?? 0;
                    final stock = (data['stock'] as num?)?.toInt() ?? 0;
                    inventoryValuation += (price * stock);
                  }

                  // 3. Total Sales Value & 4. Total Pending Orders (for this seller)
                  double totalSalesValue = 0;
                  int pendingOrdersCount = 0;
                  
                  for (var doc in ordersDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final items = data['items'] as List<dynamic>? ?? [];
                    final status = data['status'] ?? 'pending';
                    
                    bool hasSellerItems = false;
                    for (var item in items) {
                      if (item['sellerId'] == user.uid) {
                        hasSellerItems = true;
                        // For sales value, count only non-cancelled/returned
                        if (!['cancelled', 'returned', 'refunded'].contains(status)) {
                           final price = (item['price'] as num?)?.toDouble() ?? 0;
                           final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                           totalSalesValue += (price * qty);
                        }
                      }
                    }

                    if (hasSellerItems && status == 'pending') {
                      pendingOrdersCount++;
                    }
                  }

                  return Column(
                    children: [
                      _buildInventoryRow('Total Products', '$totalProducts', Icons.category, Colors.blue),
                      const SizedBox(height: 12),
                      _buildInventoryRow('Inventory Valuation', '₹${NumberFormat.compact().format(inventoryValuation)}', Icons.inventory, Colors.orange),
                       const SizedBox(height: 12),
                      _buildInventoryRow('Total Sales Value', '₹${NumberFormat.compact().format(totalSalesValue)}', Icons.monetization_on, Colors.green),
                       const SizedBox(height: 12),
                      _buildInventoryRow('Pending Orders', '$pendingOrdersCount', Icons.pending_actions, Colors.red),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      )
    );
  }

  Widget _buildInventoryRow(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final userRole = user?.role ?? 'user';

    if (user == null || (userRole != 'seller' && userRole != 'admin')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seller Dashboard')),
        body: const Center(child: Text('Access denied: Sellers only')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100], // Increased contrast from white cards
      appBar: AppBar(
        title: const Text('Seller Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('toUserId', isEqualTo: user?.uid)
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      if (user == null) return;
                      showDialog(
                        context: context,
                        builder: (context) => NotificationsDialog(userId: user.uid),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            }
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Welcome Header
            _buildWelcomeHeader(user),
            const SizedBox(height: 24),

            // 2. Key Stats Grid
            const Text(
              'Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _buildStatsGrid(user),
            const SizedBox(height: 24),

            // 3. Quick Actions Grid
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _buildQuickActionsGrid(context, user),
            const SizedBox(height: 24),

            // 4. Low Stock Alert (Horizontal Scroll)
            StreamBuilder<QuerySnapshot>(
              stream: _lowStockStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                         const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                         const SizedBox(width: 8),
                         Text(
                          'Low Stock Alert (${snapshot.data!.docs.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = snapshot.data!.docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: data['imageUrl'] != null 
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(data['imageUrl'], fit: BoxFit.cover, width: double.infinity),
                                      )
                                    : Container(color: Colors.grey[200]),
                                ),
                                const SizedBox(height: 8),
                                Text(data['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('Stock: ${data['stock']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // 5. Recent Activity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Orders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                TextButton(
                  onPressed: () => _showViewOrdersDialog(context, user),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRecentOrdersList(user),
            const SizedBox(height: 80), // Added padding for better scrolling visibility
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(AppUser user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[800]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'S',
              style: TextStyle(
                fontSize: 28,
                color: Colors.blue[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(color: Colors.blue[100], fontSize: 14),
                ),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('SELLER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(AppUser user) {
    return Column(
      children: [
        Row(
          children: [

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _deliveredOrdersStream,
                builder: (context, snapshot) {
                  double totalRevenue = 0;
                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final items = data['items'] as List<dynamic>? ?? [];
                      for (var item in items) {
                        if (item['sellerId'] == user.uid) {
                          final price = (item['price'] as num?)?.toDouble() ?? 0;
                          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                          totalRevenue += price * quantity;
                        }
                      }
                    }
                  }
                  return _buildModernStatCard('Revenue', '₹${totalRevenue.toStringAsFixed(0)}', Icons.currency_rupee, Colors.green, Colors.green[50]!);
                },
              ),
            ),

            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _ordersStream,
                builder: (context, snapshot) {
                  int count = 0;
                  if (snapshot.hasData) {
                     for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final items = data['items'] as List<dynamic>? ?? [];
                        if (items.any((item) => item['sellerId'] == user.uid)) {
                          count++;
                        }
                     }
                  }
                  return _buildModernStatCard('Total Orders', '$count', Icons.shopping_bag, Colors.blue, Colors.blue[50]!);
                },
              ),
            ),
            const SizedBox(width: 12),
             Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _productsStream,
                builder: (context, snapshot) {
                  int count = snapshot.data?.docs.length ?? 0;
                  return _buildModernStatCard('Products', '$count', Icons.inventory_2, Colors.purple, Colors.purple[50]!);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, AppUser user) {
    final actions = [
      {
        'title': 'Add Product',
        'icon': Icons.add_box,
        'color': Colors.blue,
        'onTap': () => _showAddProductDialog(context, user),
      },
      {
        'title': 'Manage Products',
        'icon': Icons.edit_note,
        'color': Colors.orange,
        'onTap': () => _showManageProductsDialog(context, user),
      },
      {
        'title': 'My Orders',
        'icon': Icons.list_alt,
        'color': Colors.teal,
        'onTap': () => _showViewOrdersDialog(context, user),
      },
      {
        'title': 'Analytics',
        'icon': Icons.analytics,
        'color': Colors.purple,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (context) => SellerAnalyticsScreen(user: user))),
      },
      {
        'title': 'My Wallet',
        'icon': Icons.account_balance_wallet,
        'color': Colors.indigo,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (context) => SellerWalletScreen(user: user))),
      },
      {
        'title': 'Stock Report',
        'icon': Icons.inventory,
        'color': Colors.teal,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (context) => SellerStockReportScreen(user: user))),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0, 
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: action['onTap'] as VoidCallback,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (action['color'] as Color).withOpacity(0.1),
                    ),
                    child: Icon(action['icon'] as IconData, color: action['color'] as Color, size: 28),
                 ),
                 const SizedBox(height: 8),
                 Text(
                   action['title'] as String,
                   textAlign: TextAlign.center,
                   style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                 ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentOrdersList(AppUser user) {
     return StreamBuilder<QuerySnapshot>(
        stream: _recentActivityStream,
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
           
           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                 child: const Center(child: Text('No recent activity', style: TextStyle(color: Colors.grey))),
              );
           }

           // Filter for relevant orders using a more manual approach since we can't filter the stream easily by array contains object field
           final relevantDocs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final items = data['items'] as List<dynamic>? ?? [];
              return items.any((item) => item['sellerId'] == user.uid);
           }).take(3).toList(); // Show max 3
           
           if (relevantDocs.isEmpty) {
              return Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                 child: const Center(child: Text('No orders yet', style: TextStyle(color: Colors.grey))),
              );
           }

           return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: relevantDocs.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                 final data = relevantDocs[index].data() as Map<String, dynamic>;
                 final orderId = relevantDocs[index].id;
                 final status = data['status'] ?? 'pending';
                 final items = data['items'] as List<dynamic>? ?? [];
                 
                 // Calculate value for this seller
                 double orderValue = 0;
                 int itemCount = 0;
                 for(var item in items) {
                    if (item['sellerId'] == user.uid) {
                       orderValue += ((item['price'] as num) * (item['quantity'] as num)).toDouble();
                       itemCount++;
                    }
                 }

                 Color statusColor = Colors.grey;
                 if (status == 'pending') statusColor = Colors.orange;
                 if (status == 'confirmed') statusColor = Colors.blue;
                 if (status == 'delivered') statusColor = Colors.green;
                 if (status == 'cancelled') statusColor = Colors.red;

                 return Container(
                    decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Colors.grey.withOpacity(0.3)),
                       boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IntrinsicHeight(
                      child: Row(
                         crossAxisAlignment: CrossAxisAlignment.stretch,
                         children: [
                            Container(width: 4, color: statusColor),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                   children: [
                                      Expanded(
                                         child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                               Text('Order #${orderId.substring(0,8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                               const SizedBox(height: 4),
                                               Text('$itemCount items • ₹${orderValue.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                            ],
                                         ),
                                      ),
                                      Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                         decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                         child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                   ],
                                ),
                              ),
                            ),
                         ],
                      ),
                    ),
                 );
              },
           );
        },
     );
  }
}
