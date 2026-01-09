import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/service_category_provider.dart';

class SharedServicesTab extends StatefulWidget {
  final bool canManage;
  final String? providerId;

  const SharedServicesTab({
    super.key,
    this.canManage = false,
    this.providerId,
  });

  @override
  State<SharedServicesTab> createState() => _SharedServicesTabState();
}

class _SharedServicesTabState extends State<SharedServicesTab> {
  String _serviceSearchQuery = '';
  String _serviceCategoryFilter = 'All';
  String _serviceAvailabilityFilter = 'All';
  String _servicePriceRangeFilter = 'All';
  String _servicePricingModelFilter = 'All';
  
  bool _isServiceSelectionMode = false;
  Set<String> _selectedServiceIds = {};

  late Stream<QuerySnapshot> _servicesStream;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  @override
  void didUpdateWidget(SharedServicesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.providerId != oldWidget.providerId) {
      _initializeStream();
    }
  }

  void _initializeStream() {
    Query query = FirebaseFirestore.instance.collection('services');
    if (widget.providerId != null) {
      query = query.where('providerId', isEqualTo: widget.providerId);
    }
    _servicesStream = query.orderBy('createdAt', descending: true).snapshots();
  }

  void _showAddServiceDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final basePriceCtrl = TextEditingController();
    final maxPriceCtrl = TextEditingController(); // For range pricing
    final serviceAreaCtrl = TextEditingController();
    
    String selectedCategory = 'Cleaning';
    String pricingModel = 'fixed'; // fixed, range, hourly
    bool isAvailable = true;
    bool isLoading = false;
    Uint8List? selectedImage;
    final ImagePicker picker = ImagePicker();

    Future<void> pickImage(StateSetter setState) async {
      try {
        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            selectedImage = bytes;
          });
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking image: $e')),
          );
        }
      }
    }

    Future<String?> uploadImage(String serviceId) async {
      if (selectedImage == null) return null;
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('services')
            .child(serviceId)
            .child('image.jpg');
        await ref.putData(selectedImage!);
        return await ref.getDownloadURL();
      } catch (e) {
        if (kDebugMode) {
          print('Error uploading image: $e');
        }
        return null;
      }
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
                        const Text(
                          'Add New Service',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Service Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Service Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Required';
                        if (v!.length < 3) return 'Minimum 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Pricing Model and Category
                    // Pricing Model and Category
                    Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: pricingModel,
                          decoration: const InputDecoration(
                            labelText: 'Pricing Model',
                            border: OutlineInputBorder(),
                          ),
                          items: ['fixed', 'range', 'hourly']
                              .map((m) => DropdownMenuItem(
                                  value: m, child: Text(m.toUpperCase())))
                              .toList(),
                          onChanged: (val) => setState(() => pricingModel = val!),
                        ),
                        const SizedBox(height: 16),
                        Consumer<ServiceCategoryProvider>(
                          builder: (context, provider, _) {
                            if (provider.serviceCategories.isEmpty) {
                              return DropdownButtonFormField<String>(
                                value: selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: ['Cleaning', 'Plumbing', 'Electrical', 'Carpentry', 'Other']
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (val) => setState(() => selectedCategory = val!),
                              );
                            }
                            return DropdownButtonFormField<String>(
                              value: provider.serviceCategories
                                      .any((cat) => cat.name == selectedCategory)
                                  ? selectedCategory
                                  : provider.serviceCategories.first.name,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: provider.serviceCategories
                                  .map((cat) => DropdownMenuItem(
                                      value: cat.name, child: Text(cat.name)))
                                  .toList(),
                              onChanged: (val) => setState(() => selectedCategory = val!),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Base Price and Max Price (conditional)
                    // Base Price and Max Price (conditional)
                    Column(
                      children: [
                        TextFormField(
                          controller: basePriceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Base Price *',
                            border: OutlineInputBorder(),
                            prefixText: '₹',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v?.isEmpty == true) return 'Required';
                            final price = double.tryParse(v!);
                            if (price == null || price <= 0) return 'Invalid price';
                            return null;
                          },
                        ),
                        if (pricingModel == 'range') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: maxPriceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Max Price',
                              border: OutlineInputBorder(),
                              prefixText: '₹',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v?.isEmpty == true) return null;
                              final maxPrice = double.tryParse(v!);
                              final basePrice = double.tryParse(basePriceCtrl.text);
                              if (maxPrice != null && basePrice != null && maxPrice <= basePrice) {
                                return 'Must be > Base Price';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Service Area
                    TextFormField(
                      controller: serviceAreaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Service Area / Pincode',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Available Toggle
                    SwitchListTile(
                      title: const Text('Service Available'),
                      value: isAvailable,
                      onChanged: (val) => setState(() => isAvailable = val),
                    ),
                    const SizedBox(height: 16),
                    
                    // Image Upload
                    OutlinedButton.icon(
                      onPressed: () => pickImage(setState),
                      icon: const Icon(Icons.image),
                      label: Text(selectedImage == null 
                          ? 'Select Image' 
                          : 'Image selected'),
                    ),
                    if (selectedImage != null) ...[
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Image.memory(
                            selectedImage!,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(() {
                                  selectedImage = null;
                                });
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  
                                  setState(() => isLoading = true);
                                  
                                  try {
                                    final serviceData = {
                                      'name': nameCtrl.text,
                                      'description': descCtrl.text,
                                      'category': selectedCategory,
                                      'pricingModel': pricingModel,
                                      'basePrice': double.parse(basePriceCtrl.text),
                                      'serviceArea': serviceAreaCtrl.text,
                                      'isAvailable': isAvailable,
                                      'providerId': 'admin', // Or current user ID if applicable
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    };
                                    
                                    if (pricingModel == 'range' && maxPriceCtrl.text.isNotEmpty) {
                                      serviceData['maxPrice'] = double.parse(maxPriceCtrl.text);
                                    }
                                    
                                    // Create service document
                                    final docRef = await FirebaseFirestore.instance
                                        .collection('services')
                                        .add(serviceData);
                                    
                                    // Upload image if any
                                    if (selectedImage != null) {
                                      final imageUrl = await uploadImage(docRef.id);
                                      if (imageUrl != null) {
                                        await docRef.update({'imageUrl': imageUrl});
                                      }
                                    }
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Service added successfully')),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Add Service'),
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

  void _showEditServiceDialog(String serviceId, Map<String, dynamic> serviceData) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: serviceData['name']);
    final descCtrl = TextEditingController(text: serviceData['description']);
    final basePriceCtrl = TextEditingController(text: serviceData['basePrice'].toString());
    final maxPriceCtrl = TextEditingController(
      text: serviceData['maxPrice']?.toString() ?? '',
    );
    
    String selectedCategory = serviceData['category'] ?? 'Cleaning';
    String pricingModel = serviceData['pricingModel'] ?? 'fixed';
    bool isAvailable = serviceData['isAvailable'] ?? true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width > 600 ? 600 : double.maxFinite,
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
                        const Text(
                          'Edit Service',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Service Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Service Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Pricing Model and Category
                    // Pricing Model and Category
                    Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: pricingModel,
                          decoration: const InputDecoration(
                            labelText: 'Pricing Model',
                            border: OutlineInputBorder(),
                          ),
                          items: ['fixed', 'range', 'hourly']
                              .map((m) => DropdownMenuItem(value: m, child: Text(m.toUpperCase())))
                              .toList(),
                          onChanged: (val) => setState(() => pricingModel = val!),
                        ),
                        const SizedBox(height: 16),
                        Consumer<ServiceCategoryProvider>(
                          builder: (context, provider, _) {
                             if (provider.serviceCategories.isEmpty) {
                              return DropdownButtonFormField<String>(
                                value: selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: ['Cleaning', 'Plumbing', 'Electrical', 'Carpentry', 'Other']
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (val) => setState(() => selectedCategory = val!),
                              );
                            }
                            return DropdownButtonFormField<String>(
                              value: provider.serviceCategories
                                      .any((cat) => cat.name == selectedCategory)
                                  ? selectedCategory
                                  : provider.serviceCategories.first.name,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: provider.serviceCategories
                                  .map((cat) => DropdownMenuItem(
                                      value: cat.name, child: Text(cat.name)))
                                  .toList(),
                              onChanged: (val) => setState(() => selectedCategory = val!),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Base Price and Max Price (conditional)
                    // Base Price and Max Price (conditional)
                    Column(
                      children: [
                        TextFormField(
                          controller: basePriceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Base Price *',
                            border: OutlineInputBorder(),
                            prefixText: '₹',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v?.isEmpty == true) return 'Required';
                            final price = double.tryParse(v!);
                            if (price == null || price <= 0) return 'Invalid price';
                            return null;
                          },
                        ),
                        if (pricingModel == 'range') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: maxPriceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Max Price',
                              border: OutlineInputBorder(),
                              prefixText: '₹',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Available Toggle
                    SwitchListTile(
                      title: const Text('Service Available'),
                      value: isAvailable,
                      onChanged: (val) => setState(() => isAvailable = val),
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  
                                  setState(() => isLoading = true);
                                  
                                  try {
                                    final updateData = {
                                      'name': nameCtrl.text,
                                      'description': descCtrl.text,
                                      'basePrice': double.parse(basePriceCtrl.text),
                                      'category': selectedCategory,
                                      'pricingModel': pricingModel,
                                      'isAvailable': isAvailable,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    };
                                    
                                    if (pricingModel == 'range' && maxPriceCtrl.text.isNotEmpty) {
                                      updateData['maxPrice'] = double.parse(maxPriceCtrl.text);
                                    }
                                    
                                    await FirebaseFirestore.instance
                                        .collection('services')
                                        .doc(serviceId)
                                        .update(updateData);
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Service updated successfully')),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save Changes'),
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

  Future<void> _bulkDeleteServices() async {
    final count = _selectedServiceIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count Service${count > 1 ? 's' : ''}?'),
        content: const Text(
          'This action cannot be undone. All selected services will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (var id in _selectedServiceIds) {
          batch.delete(FirebaseFirestore.instance.collection('services').doc(id));
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count service${count > 1 ? 's' : ''} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _selectedServiceIds.clear();
            _isServiceSelectionMode = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error splitting services: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showBulkEditDialog() {
    // Basic bulk edit implementation (simplified)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Edit Services'),
        content: const Text('Select a property to edit for all selected services.'),
        actions: [
            TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          // Implementation of actual bulk edit logic would go here
          // For now, just a placeholder as it requires complex UI
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _servicesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var services = snapshot.data?.docs ?? [];

        // 1. Search Filter
        if (_serviceSearchQuery.isNotEmpty) {
          services = services.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] as String?)?.toLowerCase() ?? '';
            return name.contains(_serviceSearchQuery.toLowerCase());
          }).toList();
        }

        // 2. Category Filter
        if (_serviceCategoryFilter != 'All') {
          services = services.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['category'] as String?) == _serviceCategoryFilter;
          }).toList();
        }

        // 3. Availability Filter
        if (_serviceAvailabilityFilter != 'All') {
          final isAvailable = _serviceAvailabilityFilter == 'Available';
          services = services.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['isAvailable'] as bool?) == isAvailable;
          }).toList();
        }

        // 4. Price Range Filter
        if (_servicePriceRangeFilter != 'All') {
          services = services.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final price = (data['basePrice'] as num?)?.toDouble() ?? 0.0;
            switch (_servicePriceRangeFilter) {
              case 'Under ₹500': return price < 500;
              case '₹500 - ₹2000': return price >= 500 && price <= 2000;
              case '₹2000 - ₹5000': return price > 2000 && price <= 5000;
              case 'Above ₹5000': return price > 5000;
              default: return true;
            }
          }).toList();
        }

        // 5. Pricing Model Filter
        if (_servicePricingModelFilter != 'All') {
          services = services.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['pricingModel'] as String?)?.toLowerCase() == _servicePricingModelFilter.toLowerCase();
          }).toList();
        }

        return Column(
          children: [
            // Filters and Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Row 1: Search and Add Button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search Services...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (val) => setState(() => _serviceSearchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (widget.canManage)
                        ElevatedButton.icon(
                          onPressed: () => _showAddServiceDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Row 2: Advanced Filters (Categories, etc)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Category Filter
                        Consumer<ServiceCategoryProvider>(
                          builder: (context, provider, _) => DropdownButton<String>(
                            value: _serviceCategoryFilter,
                            hint: const Text('Category'),
                            onChanged: (val) => setState(() => _serviceCategoryFilter = val!),
                            items: [
                              const DropdownMenuItem(value: 'All', child: Text('All Categories')),
                              ...provider.serviceCategories.map((c) => 
                                DropdownMenuItem(value: c.name, child: Text(c.name))
                              ),
                              // Fallback mostly for existing data if categories changed
                              if (!provider.serviceCategories.any((c) => c.name == 'Cleaning'))
                                 const DropdownMenuItem(value: 'Cleaning', child: Text('Cleaning')),
                              if (!provider.serviceCategories.any((c) => c.name == 'Plumbing'))
                                 const DropdownMenuItem(value: 'Plumbing', child: Text('Plumbing')),
                            ].toSet().toList(), // Remove duplicates
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Availability Filter
                        DropdownButton<String>(
                          value: _serviceAvailabilityFilter,
                          onChanged: (val) => setState(() => _serviceAvailabilityFilter = val!),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Status')),
                            DropdownMenuItem(value: 'Available', child: Text('Available Only')),
                            DropdownMenuItem(value: 'Unavailable', child: Text('Unavailable Only')),
                          ],
                        ),
                        const SizedBox(width: 16),
                        
                        // Price Range
                        DropdownButton<String>(
                          value: _servicePriceRangeFilter,
                          onChanged: (val) => setState(() => _servicePriceRangeFilter = val!),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('Any Price')),
                            DropdownMenuItem(value: 'Under ₹500', child: Text('Under ₹500')),
                            DropdownMenuItem(value: '₹500 - ₹2000', child: Text('₹500 - ₹2000')),
                            DropdownMenuItem(value: '₹2000 - ₹5000', child: Text('₹2000 - ₹5000')),
                            DropdownMenuItem(value: 'Above ₹5000', child: Text('Above ₹5000')),
                          ],
                        ),
                        const SizedBox(width: 16),
                        
                         // Pricing Model
                         DropdownButton<String>(
                          value: _servicePricingModelFilter,
                          onChanged: (val) => setState(() => _servicePricingModelFilter = val!),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Models')),
                            DropdownMenuItem(value: 'fixed', child: Text('Fixed Price')),
                            DropdownMenuItem(value: 'range', child: Text('Range')),
                            DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Header stats & Bulk actions
            Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Text(
                      'Total Services: ${services.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (widget.canManage)
                      Row(
                        children: [
                          if (!_isServiceSelectionMode)
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isServiceSelectionMode = true;
                                });
                              },
                              icon: const Icon(Icons.check_box_outlined),
                              label: const Text('Select Mode'),
                            )
                          else ...[
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isServiceSelectionMode = false;
                                  _selectedServiceIds.clear();
                                });
                              },
                              child: const Text('Cancel Selection'),
                            ),
                            const SizedBox(width: 8),
                            if (_selectedServiceIds.isNotEmpty) ...[
                              ElevatedButton.icon(
                                onPressed: _showBulkEditDialog,
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit Selected'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _bulkDeleteServices,
                                icon: const Icon(Icons.delete),
                                label: Text('Delete (${_selectedServiceIds.length})'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                 ],
               ),
            ),
            
            if (_isServiceSelectionMode)
              Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 child: Row(
                   children: [
                      Checkbox(
                        value: _selectedServiceIds.length == services.length && services.isNotEmpty,
                        onChanged: (val) {
                          setState(() {
                             if (val == true) {
                               _selectedServiceIds = services.map((s) => s.id).toSet();
                             } else {
                               _selectedServiceIds.clear();
                             }
                          });
                        },
                      ),
                      const Text('Select All'),
                   ],
                 ),
              ),

             // List
            Expanded(
              child: services.isEmpty
                  ? const Center(child: Text('No services found matching filters'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        final service = services[index];
                        final data = service.data() as Map<String, dynamic>;
                        final isSelected = _selectedServiceIds.contains(service.id);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: _isServiceSelectionMode && isSelected
                                ? const BorderSide(color: Colors.blue, width: 2)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: _isServiceSelectionMode
                                ? () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedServiceIds.remove(service.id);
                                      } else {
                                        _selectedServiceIds.add(service.id);
                                      }
                                    });
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_isServiceSelectionMode)
                                     Checkbox(
                                        value: isSelected,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedServiceIds.add(service.id);
                                            } else {
                                              _selectedServiceIds.remove(service.id);
                                            }
                                          });
                                        },
                                     ),
                                  // Image
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: data['imageUrl'] != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              data['imageUrl'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (c,e,s) => const Icon(Icons.broken_image),
                                            ),
                                          )
                                        : const Icon(Icons.handyman, size: 40),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Detail
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                data['name'] ?? 'Untitled',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: data['isAvailable'] == true 
                                                    ? Colors.green.withOpacity(0.1)
                                                    : Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: data['isAvailable'] == true ? Colors.green : Colors.red,
                                                ),
                                              ),
                                              child: Text(
                                                data['isAvailable'] == true ? 'Active' : 'Inactive',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: data['isAvailable'] == true ? Colors.green : Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Category: ${data['category'] ?? 'Uncategorized'}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data['pricingModel'] == 'range'
                                              ? '₹${data['basePrice']} - ₹${data['maxPrice']}'
                                              : '₹${data['basePrice']} (${data['pricingModel']})',
                                           style: const TextStyle(
                                             fontWeight: FontWeight.bold,
                                             color: Colors.blue,
                                           ),
                                        ),
                                        if (data['description'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            data['description'],
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  
                                  // Actions
                                  if (widget.canManage && !_isServiceSelectionMode)
                                     PopupMenuButton<String>(
                                       onSelected: (value) async {
                                         if (value == 'edit') {
                                           _showEditServiceDialog(service.id, data);
                                         } else if (value == 'delete') {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Delete Service'),
                                                content: Text('Are you sure you want to delete "${data['name']}"?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            
                                            if (confirm == true) {
                                              await FirebaseFirestore.instance.collection('services').doc(service.id).delete();
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service deleted')));
                                              }
                                            }
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
                                     ),
                                ],
                              ),
                            ),
                          ),
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
