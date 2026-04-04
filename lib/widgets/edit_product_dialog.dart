import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';

class EditProductDialog extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const EditProductDialog({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _basePriceController; // Added
  late TextEditingController _mrpController;
  late TextEditingController _stockController;
  late TextEditingController _minQtyController;
  late TextEditingController _maxQtyController;
  late TextEditingController _adminProfitPercentageController; // Added
  
  late String _selectedCategory;
  late String _selectedUnit;
  List<String> _existingImageUrls = [];
  List<Uint8List> _newImages = []; // Bytes for web/mobile compatibility
  List<String> _selectedStoreIds = []; // Added for store linking
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.productData['name']);
    _descriptionController = TextEditingController(text: widget.productData['description']);
    // Prefer sellerPrice (price without fee) for the input field if it exists
    final initialPrice = (widget.productData['sellerPrice'] as num?)?.toDouble() ?? 
                       (widget.productData['price'] as num?)?.toDouble() ?? 0.0;
    _priceController = TextEditingController(text: initialPrice.toString());
    _basePriceController = TextEditingController(text: (widget.productData['basePrice'] ?? 0.0).toString()); // Added
    _mrpController = TextEditingController(text: (widget.productData['mrp'] ?? initialPrice).toString());
    _stockController = TextEditingController(text: widget.productData['stock'].toString());
    _minQtyController = TextEditingController(text: (widget.productData['minimumQuantity'] ?? 1).toString());
    _maxQtyController = TextEditingController(text: (widget.productData['maximumQuantity'] ?? 0).toString());
    _adminProfitPercentageController = TextEditingController(
      text: (widget.productData['adminProfitPercentage'] as num?)?.toString() ?? '',
    );
    _selectedCategory = widget.productData['category'] ?? 'Daily Needs';
    _selectedUnit = widget.productData['unit'] ?? 'Pic';
    _existingImageUrls = List<String>.from(widget.productData['imageUrls'] ?? (widget.productData['imageUrl'] != null ? [widget.productData['imageUrl']] : []));
    _selectedStoreIds = List<String>.from(widget.productData['storeIds'] ?? []); // Init storeIds
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _basePriceController.dispose(); // Added
    _mrpController.dispose();
    _stockController.dispose();
    _minQtyController.dispose();
    _maxQtyController.dispose();
    _adminProfitPercentageController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final List<Uint8List> imageBytes = [];
        for (var image in images.take(6 - _existingImageUrls.length - _newImages.length)) {
          final bytes = await image.readAsBytes();
          imageBytes.add(bytes);
        }
        setState(() {
          _newImages.addAll(imageBytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
      }
    }
  }

  Future<List<String>> _uploadNewImages() async {
    List<String> urls = [];
    for (int i = 0; i < _newImages.length; i++) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('products')
            .child(widget.productId)
            .child('update_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        
        await ref.putData(_newImages[i], SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        urls.add(url);
    }
    return urls;
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate at least one image exists (either existing or new)
    if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product must have at least one image')));
        return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload new images
      List<String> newUrls = await _uploadNewImages();
      List<String> allUrls = [..._existingImageUrls, ...newUrls];

      final sellingPrice = double.parse(_priceController.text);
      final mrp = double.tryParse(_mrpController.text) ?? sellingPrice;
      double discountPercent = 0;
      if (mrp > sellingPrice && mrp > 0) {
        discountPercent = ((mrp - sellingPrice) / mrp) * 100;
      }

      await FirebaseFirestore.instance.collection('products').doc(widget.productId).update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'basePrice': double.parse(_basePriceController.text),
        'price': sellingPrice, // Store Selling Price directly
        'sellerPrice': sellingPrice, 
        'discountPercent': discountPercent > 0 ? discountPercent : null,
        'mrp': mrp,
        'isHotDeal': mrp > sellingPrice,
        'stock': int.parse(_stockController.text),
        'minimumQuantity': int.parse(_minQtyController.text),
        'maximumQuantity': int.parse(_maxQtyController.text),
        'category': _selectedCategory,
        'unit': _selectedUnit,
        'storeIds': _selectedStoreIds, // Save storeIds
        'imageUrls': allUrls,
        'imageUrl': allUrls.isNotEmpty ? allUrls.first : null, // Main image
        'adminProfitPercentage': _adminProfitPercentageController.text.isNotEmpty 
            ? double.tryParse(_adminProfitPercentageController.text) 
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // --- LOG STOCK INCREASE AS PURCHASE ---
      final newStock = int.parse(_stockController.text);
      final oldStock = (widget.productData['stock'] as num?)?.toInt() ?? 0;
      final bPrice = double.parse(_basePriceController.text);
      
      if (newStock > oldStock) {
          final diff = newStock - oldStock;
          for (var sId in _selectedStoreIds) {
            await FirebaseFirestore.instance.collection('purchases').add({
              'productId': widget.productId,
              'productName': _nameController.text.trim(),
              'quantity': diff,
              'purchasePrice': bPrice,
              'totalAmount': diff * bPrice,
              'storeId': sId,
              'type': 'restock',
              'createdAt': FieldValue.serverTimestamp(),
              'state': widget.productData['state'],
            });
          }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated successfully')));
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Product'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? 500
              : MediaQuery.of(context).size.width * 0.95,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Management
                const Text('Images', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Existing Images
                      ..._existingImageUrls.asMap().entries.map((entry) {
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(entry.value),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 0,
                              child: InkWell(
                                onTap: () => setState(() => _existingImageUrls.removeAt(entry.key)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      // New Images
                      ..._newImages.asMap().entries.map((entry) {
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(entry.value, fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 0,
                              child: InkWell(
                                onTap: () => setState(() => _newImages.removeAt(entry.key)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      // Add Button
                      if ((_existingImageUrls.length + _newImages.length) < 6)
                        InkWell(
                          onTap: _pickImages,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Fields
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 3,
                  onChanged: (value) {
                    if (value.endsWith('\n')) {
                       _descriptionController.text = '$value\u2022 ';
                       _descriptionController.selection = TextSelection.fromPosition(TextPosition(offset: _descriptionController.text.length));
                    } else if (value.isEmpty) {
                       _descriptionController.text = '\u2022 ';
                       _descriptionController.selection = TextSelection.fromPosition(TextPosition(offset: _descriptionController.text.length));
                    }
                  },
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _basePriceController,
                            decoration: const InputDecoration(labelText: 'Base Price (Buying)', prefixText: '\u20B9', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _mrpController,
                            decoration: const InputDecoration(labelText: 'MRP', prefixText: '\u20B9', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                     TextFormField(
                       controller: _priceController,
                       decoration: const InputDecoration(labelText: 'Selling Price', prefixText: '\u20B9', border: OutlineInputBorder()),
                       keyboardType: TextInputType.number,
                       validator: (v) {
                           if (v == null || v.isEmpty) return 'Required';
                           final price = double.tryParse(v);
                           if (price == null) return 'Invalid';
                           final mrp = double.tryParse(_mrpController.text);
                           if (mrp != null && price > mrp) return 'Price > MRP';
                           return null;
                       },
                     ),
                     const SizedBox(height: 12),
                    const SizedBox(height: 12),
                    ListenableBuilder(
                      listenable: Listenable.merge([_priceController, _mrpController]),
                      builder: (context, _) {
                        final price = double.tryParse(_priceController.text) ?? 0;
                        final mrp = double.tryParse(_mrpController.text) ?? 0;
                        if (mrp <= price || mrp <= 0) return const SizedBox.shrink();
                        
                        final discountPercent = ((mrp - price) / mrp) * 100;

                        return Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Calculated Discount: ${discountPercent.toStringAsFixed(1)}% OFF',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const Text('Inventory Details', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      items: ['Kg', 'Ltr', 'Pic', 'Pkt', 'Grm', 'Box', 'Dozen', 'Set', 'Packet', 'Gram']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v!),
                      decoration: const InputDecoration(labelText: 'Product Unit', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            decoration: InputDecoration(labelText: 'Stock', border: const OutlineInputBorder(), suffixText: _selectedUnit),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final val = int.tryParse(v ?? '');
                              if (val == null) return 'Invalid';
                              if (val < 0) return 'Cannot be negative';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                             controller: _minQtyController,
                             decoration: InputDecoration(labelText: 'Min Order Qty', border: const OutlineInputBorder(), suffixText: _selectedUnit),
                             keyboardType: TextInputType.number,
                             validator: (v) => (v?.isEmpty == true || int.tryParse(v!) == null || int.parse(v) < 1) ? 'Min 1' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                       controller: _maxQtyController,
                       decoration: InputDecoration(labelText: 'Max Order Qty (0 for no limit)', border: const OutlineInputBorder(), suffixText: _selectedUnit),
                       keyboardType: TextInputType.number,
                       validator: (v) => (v?.isEmpty == true || int.tryParse(v!) == null || int.parse(v!) < 0) ? 'Invalid' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Store Availability (Admin/Core Staff Only)
                 Consumer<AuthProvider>(
                   builder: (context, auth, child) {
                     // Check role safely
                     final isAllowed = auth.isAdmin || auth.isCoreStaff;
                     
                     if (!isAllowed) return const SizedBox.shrink();

                     return Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text('Available in Stores:', style: TextStyle(fontWeight: FontWeight.bold)),
                         const SizedBox(height: 8),
                         StreamBuilder<QuerySnapshot>(
                           stream: FirebaseFirestore.instance.collection('stores').where('isActive', isEqualTo: true).snapshots(),
                           builder: (context, snapshot) {
                              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                              final stores = snapshot.data!.docs;
                              if (stores.isEmpty) return const Text('No active stores found.');
                              
                              // Calculate selected names for display
                              final selectedNames = stores
                                  .where((doc) => _selectedStoreIds.contains(doc.id))
                                  .map((doc) => doc['name'] as String)
                                  .join(', ');

                              return InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      // Create a temporary list to hold changes during dialog session if we wanted 'Cancel',
                                      // but live update is fine for simple usage, just update the main list.
                                      // Using StatefulBuilder to update the Checkboxes inside the dialog.
                                      return StatefulBuilder(
                                        builder: (context, setDialogState) {
                                          return AlertDialog(
                                            title: const Text('Select Stores'),
                                            content: SizedBox(
                                              width: double.maxFinite,
                                              child: ListView.builder(
                                                shrinkWrap: true,
                                                itemCount: stores.length,
                                                itemBuilder: (context, index) {
                                                  final doc = stores[index];
                                                  final storeId = doc.id;
                                                  final storeName = doc['name'] ?? 'Unknown';
                                                  final isSelected = _selectedStoreIds.contains(storeId);

                                                  return CheckboxListTile(
                                                    title: Text(storeName),
                                                    value: isSelected,
                                                    onChanged: (bool? value) {
                                                      setDialogState(() {
                                                        if (value == true) {
                                                          _selectedStoreIds.add(storeId);
                                                        } else {
                                                          _selectedStoreIds.remove(storeId);
                                                        }
                                                      });
                                                      // Also trigger parent rebuild if we want live background updates, 
                                                      // but mostly we need it when dialog closes.
                                                    },
                                                  );
                                                },
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Done'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ).then((_) {
                                    // Update parent widget to show new selected names
                                    setState(() {});
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selectedNames.isEmpty ? 'Select Stores' : selectedNames,
                                          style: TextStyle(
                                            color: selectedNames.isEmpty ? Colors.grey[700] : Colors.black87,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              );
                           },
                         ),
                        const SizedBox(height: 12),
                       ],
                     );
                   },
                 ),

                const SizedBox(height: 12),
                // Admin Profit Sharing % (Visible only to Admin/Super Admin)
                if (Provider.of<AuthProvider>(context, listen: false).hasAdminAccess) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _adminProfitPercentageController,
                    decoration: const InputDecoration(
                      labelText: 'Admin Profit Commission (%) [Admin Only]',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                      helperText: 'Leave empty to use system default (0%)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                ],

                Column(
                  children: [
                     Consumer<CategoryProvider>(
                        builder: (context, categoryProvider, child) {
                          final categories = categoryProvider.categories.map((c) => c.name).toList();
                          // Ensure selected category exists in the list
                          if (_selectedCategory.isNotEmpty && !categories.contains(_selectedCategory)) {
                            categories.add(_selectedCategory);
                          }
                          if (categories.isEmpty) {
                            categories.add('Daily Needs');
                          }
                          
                          return DropdownButtonFormField<String>(
                            value: categories.contains(_selectedCategory) ? _selectedCategory : categories.first,
                            isExpanded: true,
                            items: categories
                                .toSet() // Remove duplicates just in case
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedCategory = v!),
                            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                            menuMaxHeight: 300,
                          );
                        },
                      ),
                    // Removed separate Unit dropdown as it is now above in the row
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateProduct,
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Changes'),
        ),
      ],
    );
  }
}
