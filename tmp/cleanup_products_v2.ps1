$path = 'c:\Users\souna\DEMANDY\ecommerce_app\lib\widgets\shared_products_tab.dart'
$content = Get-Content $path

$newAddDialog = @"
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String? dialogError;
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
                      OutlinedButton.icon(onPressed: () => pickImages(setState), icon: const Icon(Icons.image), label: Text(_selectedImages.isEmpty ? 'Select Images' : '${_selectedImages.length} images')),
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
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              if (_selectedImages.isNotEmpty) {
                                final urls = await uploadImages(docRef.id);
                                await docRef.update({'imageUrls': urls, 'imageUrl': urls.first});
                              }
                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              setState(() {
                                isLoading = false;
                                dialogError = e.toString().toLowerCase().contains('permission') ? "?? Permission Denied: You cannot add products." : "Error: $e";
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String? dialogError;
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
                              await FirebaseFirestore.instance.collection('products').doc(productId).update({
                                'name': nameCtrl.text,
                                'description': descCtrl.text,
                                'price': sp,
                                'mrp': m,
                                'stock': int.parse(stockCtrl.text),
                                'isHotDeal': m > sp,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              setState(() {
                                isLoading = false;
                                dialogError = e.toString().toLowerCase().contains('permission') ? "?? Permission Denied: You cannot edit this product." : "Error: $e";
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
"@

$start = 1196
$end = 2701
$newContent = $content[0..($start-1)] + $newAddDialog + $content[($end+1)..($content.Count-1)]
$newContent | Set-Content $path
