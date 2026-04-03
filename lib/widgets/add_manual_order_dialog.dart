import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';

class AddManualOrderDialog extends StatefulWidget {
  const AddManualOrderDialog({super.key});

  @override
  State<AddManualOrderDialog> createState() => _AddManualOrderDialogState();
}

class _AddManualOrderDialogState extends State<AddManualOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _stateController = TextEditingController();

  List<Map<String, dynamic>> _selectedItems = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill state if user is a State Admin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isStateAdmin && auth.currentUser?.assignedState != null) {
        _stateController.text = auth.currentUser!.assignedState!;
      }
    });
  }

  double get _totalAmount {
    return _selectedItems.fold(0, (sum, item) => sum + (item['price'] * item['quantity']));
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
          'quantity': 1,
          'sellerId': product.sellerId,
          'storeIds': product.storeIds,
        });
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      if (_selectedItems[index]['quantity'] > 1) {
        _selectedItems[index]['quantity']--;
      } else {
        _selectedItems.removeAt(index);
      }
    });
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
        'pincode': _pincodeController.text.trim(), // Keep legacy field just in case
        'state': _stateController.text.trim(),
        'items': _selectedItems,
        'sellerIds': sellerIds,
        'totalAmount': _totalAmount,
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
    final products = context.watch<ProductProvider>().products;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add Manual Order (Guest)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Customer Info
                      const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Full Address', border: OutlineInputBorder()),
                        maxLines: 2,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _pincodeController,
                              decoration: const InputDecoration(labelText: 'Pincode', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _stateController,
                              decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Product Selection
                      const Text('Select Products', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Autocomplete<Product>(
                        displayStringForOption: (p) => p.name,
                        optionsBuilder: (textEditingValue) async {
                          if (textEditingValue.text.trim().isEmpty) return const Iterable<Product>.empty();
                          final productProvider = Provider.of<ProductProvider>(context, listen: false);
                          return await productProvider.searchProductsGlobal(textEditingValue.text.trim());
                        },
                        onSelected: _addItem,
                        fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
                          return TextField(
                            controller: ctrl,
                            focusNode: focus,
                            decoration: const InputDecoration(
                              hintText: 'Search product by name...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      
                      // Selected Items List
                      if (_selectedItems.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _selectedItems.length,
                          itemBuilder: (ctx, i) {
                            final item = _selectedItems[i];
                            return ListTile(
                              leading: item['productImageUrl'] != null 
                                ? Image.network(item['productImageUrl'], width: 40)
                                : const Icon(Icons.image),
                              title: Text(item['productName']),
                              subtitle: Text('₹${item['price']} x ${item['quantity']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _removeItem(i)),
                                  IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () {
                                    setState(() => _selectedItems[i]['quantity']++);
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold))),
                      Text('₹${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveOrder,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      child: _isSaving 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('CREATE ORDER'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
