import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';

class AdminAddEditProductScreen extends StatefulWidget {
  static const routeName = '/admin/add-edit-product';

  final String? productId;
  final Map<String, dynamic>? productData;
  final String? storeId;

  const AdminAddEditProductScreen({
    super.key,
    this.productId,
    this.productData,
    this.storeId,
  });

  @override
  State<AdminAddEditProductScreen> createState() => _AdminAddEditProductScreenState();
}

class _AdminAddEditProductScreenState extends State<AdminAddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _basePriceCtrl;
  late TextEditingController _mrpCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _minQtyCtrl;
  late TextEditingController _maxQtyCtrl;
  late TextEditingController _adminProfitPercentageCtrl;
  late TextEditingController _servicePincodesCtrl;

  String _selectedCategory = '';
  String _selectedUnit = 'Pic';
  String _minUnit = 'Pic';
  String _maxUnit = 'Pic';
  bool _isFeatured = false;
  bool _isCustomerChoice = false;
  bool _isLoading = false;
  List<Uint8List> _selectedImages = [];
  List<String> _existingImageUrls = [];
  
  @override
  void initState() {
    super.initState();
    final data = widget.productData;
    
    _nameCtrl = TextEditingController(text: data?['name'] ?? '');
    _descCtrl = TextEditingController(text: data?['description'] ?? '\u2022 ');
    _basePriceCtrl = TextEditingController(text: (data?['basePrice'] ?? 0.0).toString());
    _mrpCtrl = TextEditingController(text: (data?['mrp'] ?? 0.0).toString());
    _priceCtrl = TextEditingController(text: (data?['price'] ?? 0.0).toString());
    _stockCtrl = TextEditingController(text: (data?['stock'] ?? 0.0).toString());
    _minQtyCtrl = TextEditingController(text: (data?['minimumQuantity'] ?? 1.0).toString());
    _maxQtyCtrl = TextEditingController(text: (data?['maximumQuantity'] ?? 0.0).toString());
    _adminProfitPercentageCtrl = TextEditingController(text: (data?['adminProfitPercentage'] as num?)?.toString() ?? '');
    _servicePincodesCtrl = TextEditingController(text: (data?['servicePincodes'] as List<dynamic>?)?.join(', ') ?? '');

    _selectedCategory = data?['category'] ?? '';
    _selectedUnit = data?['unit'] ?? 'Pic';
    _minUnit = _selectedUnit;
    _maxUnit = _selectedUnit;
    _isFeatured = data?['isFeatured'] ?? false;
    _isCustomerChoice = data?['isCustomerChoice'] ?? false;
    _existingImageUrls = List<String>.from(data?['imageUrls'] ?? []);

    if (widget.productId == null) {
      // Auto-fill service area for Store Partners if adding new
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isStorePartner) {
        _servicePincodesCtrl.text = auth.currentUser?.servicePincodes.join(', ') ?? '';
      }
    } else {
       // Auto-detect sub-units for editing
       _detectSubUnits();
    }
  }

  void _detectSubUnits() {
    double minV = double.tryParse(_minQtyCtrl.text) ?? 1.0;
    if (_selectedUnit == 'Kg' && minV < 1.0 && minV > 0) {
      _minUnit = 'Grm';
      _minQtyCtrl.text = (minV * 1000).toStringAsFixed(0);
    } else if (_selectedUnit == 'Ltr' && minV < 1.0 && minV > 0) {
      _minUnit = 'Ml';
      _minQtyCtrl.text = (minV * 1000).toStringAsFixed(0);
    }

    double maxV = double.tryParse(_maxQtyCtrl.text) ?? 0.0;
    if (_selectedUnit == 'Kg' && maxV > 0 && maxV < 1.0) {
      _maxUnit = 'Grm';
      _maxQtyCtrl.text = (maxV * 1000).toStringAsFixed(0);
    } else if (_selectedUnit == 'Ltr' && maxV > 0 && maxV < 1.0) {
      _maxUnit = 'Ml';
      _maxQtyCtrl.text = (maxV * 1000).toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _basePriceCtrl.dispose();
    _mrpCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _minQtyCtrl.dispose();
    _maxQtyCtrl.dispose();
    _adminProfitPercentageCtrl.dispose();
    _servicePincodesCtrl.dispose();
    super.dispose();
  }

  double _getConvertedValue(double value, String unit, String mainUnit) {
    if ((mainUnit == 'Kg' && unit == 'Grm') || (mainUnit == 'Ltr' && unit == 'Ml')) {
      return value / 1000.0;
    }
    return value;
  }

  List<String> _getQtyUnitOptions(String mainUnit) {
    if (mainUnit == 'Kg') return ['Kg', 'Grm'];
    if (mainUnit == 'Ltr') return ['Ltr', 'Ml'];
    return [mainUnit];
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await ImagePicker().pickMultiImage();
      if (images.isNotEmpty) {
        final List<Uint8List> imageBytes = [];
        int currentTotal = _selectedImages.length + _existingImageUrls.length;
        for (var image in images.take(6 - currentTotal)) {
          final bytes = await image.readAsBytes();
          if (bytes.length > 800 * 1024) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image ${image.name} exceeds 800 KB limit.')));
             continue;
          }
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

  Future<List<String>> _uploadImages(String productId) async {
    List<String> urls = List.from(_existingImageUrls);
    for (int i = 0; i < _selectedImages.length; i++) {
        final ref = FirebaseStorage.instance.ref().child('products').child(productId).child('img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        await ref.putData(_selectedImages[i], SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        urls.add(url);
    }
    return urls;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final sp = double.parse(_priceCtrl.text);
      final m = double.tryParse(_mrpCtrl.text) ?? sp;
      
      final productData = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': sp,
        'mrp': m,
        'basePrice': double.tryParse(_basePriceCtrl.text) ?? 0.0,
        'stock': double.parse(_stockCtrl.text),
        'category': _selectedCategory,
        'unit': _selectedUnit,
        'isFeatured': _isFeatured,
        'isHotDeal': m > sp,
        'isCustomerChoice': _isCustomerChoice,
        'storeIds': widget.productId != null 
            ? List<String>.from(widget.productData?['storeIds'] ?? [])
            : (widget.storeId != null ? [widget.storeId!] : []),
        'servicePincodes': _servicePincodesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'adminProfitPercentage': _adminProfitPercentageCtrl.text.isNotEmpty 
            ? double.tryParse(_adminProfitPercentageCtrl.text) 
            : null,
        'minimumQuantity': _getConvertedValue(double.parse(_minQtyCtrl.text), _minUnit, _selectedUnit),
        'maximumQuantity': _getConvertedValue(double.parse(_maxQtyCtrl.text), _maxUnit, _selectedUnit),
      };

      String productId = widget.productId ?? '';
      DocumentReference docRef;
      
      if (widget.productId == null) {
        // Create new
        productData['salesCount'] = 0;
        productData['sellerId'] = auth.isAdmin ? 'admin' : auth.currentUser?.uid ?? 'partner';
        productData['createdAt'] = FieldValue.serverTimestamp();
        productData['state'] = auth.currentUser?.state;
        
        docRef = await FirebaseFirestore.instance.collection('products').add(productData);
        productId = docRef.id;
      } else {
        // Update existing
        productData['updatedAt'] = FieldValue.serverTimestamp();
        docRef = FirebaseFirestore.instance.collection('products').doc(productId);
        await docRef.update(productData);
      }

      // Handle Image Uploads
      final finalUrls = await _uploadImages(productId);
      await docRef.update({
        'imageUrls': finalUrls,
        'imageUrl': finalUrls.isNotEmpty ? finalUrls.first : null,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.productId == null ? 'Product added successfully!' : 'Product updated successfully!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = Provider.of<CategoryProvider>(context).categories;
    if (_selectedCategory.isEmpty && categories.isNotEmpty) {
      _selectedCategory = categories.first.name;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? 'Add Product' : 'Edit Product'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameCtrl, 
                      decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()), 
                      validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descCtrl, 
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), 
                      maxLines: 3
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _basePriceCtrl, decoration: const InputDecoration(labelText: 'Base Price', border: OutlineInputBorder(), prefixText: '₹'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: _mrpCtrl, decoration: const InputDecoration(labelText: 'MRP', border: OutlineInputBorder(), prefixText: '₹'), keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceCtrl, 
                      decoration: const InputDecoration(labelText: 'Selling Price *', border: OutlineInputBorder(), prefixText: '₹'), 
                      keyboardType: TextInputType.number, 
                      validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _servicePincodesCtrl, 
                      decoration: const InputDecoration(
                        labelText: 'Service Area Pincodes *', 
                        hintText: 'e.g. 742223, 742212',
                        border: OutlineInputBorder(),
                        helperText: 'Only customers in these areas can see this product',
                      ),
                      validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedUnit, 
                      decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()), 
                      items: ['Kg','Ltr','Pic','Pkt','Grm','Box'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), 
                      onChanged: (v) => setState(() {
                         _selectedUnit = v!;
                         _minUnit = v;
                         _maxUnit = v;
                      })
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _stockCtrl, decoration: const InputDecoration(labelText: 'Stock *', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: TextFormField(controller: _minQtyCtrl, decoration: const InputDecoration(labelText: 'Min Qty', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 70,
                                child: DropdownButtonFormField<String>(
                                  value: _minUnit,
                                  isDense: true,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 4)),
                                  items: _getQtyUnitOptions(_selectedUnit).map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 11)))).toList(),
                                  onChanged: (v) => setState(() => _minUnit = v!),
                                ),
                              ),
                            ],
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _maxQtyCtrl, decoration: const InputDecoration(labelText: 'Max Order Qty (0 for none)', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: DropdownButtonFormField<String>(
                              value: _maxUnit,
                              isDense: true,
                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 4)),
                              items: _getQtyUnitOptions(_selectedUnit).map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 11)))).toList(),
                              onChanged: (v) => setState(() => _maxUnit = v!),
                            ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory, 
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()), 
                      items: categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(), 
                      onChanged: (v) => setState(() => _selectedCategory = v!)
                    ),
                    const SizedBox(height: 16),
                    if (Provider.of<AuthProvider>(context, listen: false).isAdmin) ...[
                      TextFormField(
                        controller: _adminProfitPercentageCtrl,
                        decoration: const InputDecoration(labelText: 'Admin Commission (%)', border: OutlineInputBorder(), helperText: 'Overrides default category commission'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                    ],
                    SwitchListTile(title: const Text('Featured Product'), value: _isFeatured, onChanged: (v) => setState(() => _isFeatured = v)),
                    SwitchListTile(title: const Text('Customer Choice'), value: _isCustomerChoice, onChanged: (v) => setState(() => _isCustomerChoice = v)),
                    const SizedBox(height: 24),
                    
                    const Text('Product Images (Max 6)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('Size: 512 x 512 px, Max: 800 KB', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._existingImageUrls.asMap().entries.map((entry) => Stack(
                          children: [
                            Image.network(entry.value, width: 80, height: 80, fit: BoxFit.cover),
                            Positioned(top: 0, right: 0, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 20), onPressed: () => setState(() => _existingImageUrls.removeAt(entry.key)), style: IconButton.styleFrom(backgroundColor: Colors.red))),
                          ],
                        )),
                        ..._selectedImages.asMap().entries.map((entry) => Stack(
                          children: [
                            Image.memory(entry.value, width: 80, height: 80, fit: BoxFit.cover),
                            Positioned(top: 0, right: 0, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 20), onPressed: () => setState(() => _selectedImages.removeAt(entry.key)), style: IconButton.styleFrom(backgroundColor: Colors.red))),
                          ],
                        )),
                        if (_existingImageUrls.length + _selectedImages.length < 6)
                          GestureDetector(
                            onTap: _pickImages,
                            child: Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.add_a_photo, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                        child: Text(widget.productId == null ? 'ADD PRODUCT' : 'SAVE CHANGES', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
