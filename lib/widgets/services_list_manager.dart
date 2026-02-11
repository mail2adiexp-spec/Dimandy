import 'package:flutter/material.dart';
import '../models/service_item_model.dart';

import '../utils/category_helpers.dart'; // Add import

class ServicesListManager extends StatefulWidget {
  final List<ServiceItem> initialServices;
  final Function(List<ServiceItem>) onServicesChanged;
  final double platformFeePercentage; // Platform fee percentage from settings
  final String? category; // Add category

  const ServicesListManager({
    super.key,
    required this.initialServices,
    required this.onServicesChanged,
    this.platformFeePercentage = 10.0, // Default 10%
    this.category, // Add to constructor
  });

  @override
  State<ServicesListManager> createState() => _ServicesListManagerState();
}

class _ServicesListManagerState extends State<ServicesListManager> {
  late List<ServiceItem> _services;

  @override
  void initState() {
    super.initState();
    _services = List.from(widget.initialServices);
  }

  bool get _isBloodTechnician {
    final cat = widget.category?.toLowerCase() ?? '';
    return cat.contains('blood') || cat.contains('technician');
  }

  bool get _isNapit {
    final cat = widget.category?.toLowerCase() ?? '';
    return cat.contains('napit') || cat.contains('barber') || cat.contains('salon');
  }

  bool get _isBeautician {
    final cat = widget.category?.toLowerCase() ?? '';
    return cat.contains('beautician') || cat.contains('beauty') || cat.contains('parlour');
  }

  bool get _isSecurity {
    final cat = widget.category?.toLowerCase() ?? '';
    return cat.contains('security') || cat.contains('guard');
  }

  void _addService() {
    showDialog(
      context: context,
      builder: (context) {
        final nameCtrl = TextEditingController();
        final priceCtrl = TextEditingController();
        final descCtrl = TextEditingController();
        final durationCtrl = TextEditingController(text: '30');
        
        // Use a local variable for the dropdown value
        String? selectedTestName;

        return StatefulBuilder( // Use StatefulBuilder to update dropdown
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Service'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isBloodTechnician)
                      DropdownButtonFormField<String>(
                        value: selectedTestName,
                        decoration: const InputDecoration(
                          labelText: 'Service Name *',
                          border: OutlineInputBorder(),
                        ),
                        items: CategoryHelpers.commonBloodTests
                            .map((test) => DropdownMenuItem(
                                  value: test,
                                  child: Text(test),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedTestName = val;
                            nameCtrl.text = val ?? '';
                            if (val != null) {
                              final price = CategoryHelpers.commonBloodTestPrices[val];
                              if (price != null) {
                                priceCtrl.text = price.toStringAsFixed(0);
                              }
                            }
                          });
                        },
                      )
                    else if (_isNapit)
                      DropdownButtonFormField<String>(
                        value: selectedTestName,
                        decoration: const InputDecoration(
                          labelText: 'Service Name *',
                          border: OutlineInputBorder(),
                        ),
                        items: CategoryHelpers.commonNapitServiceNames
                            .map((test) => DropdownMenuItem(
                                  value: test,
                                  child: Text(test),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedTestName = val;
                            nameCtrl.text = val ?? '';
                            if (val != null) {
                              final price = CategoryHelpers.commonNapitServices[val];
                              if (price != null) {
                                priceCtrl.text = price.toStringAsFixed(0);
                              }
                            }
                          });
                        },
                      )
                    else if (_isBeautician)
                      DropdownButtonFormField<String>(
                        value: selectedTestName,
                        decoration: const InputDecoration(
                          labelText: 'Service Name *',
                          border: OutlineInputBorder(),
                        ),
                        items: CategoryHelpers.commonBeauticianServiceNames
                            .map((test) => DropdownMenuItem(
                                  value: test,
                                  child: Text(test),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedTestName = val;
                            nameCtrl.text = val ?? '';
                            if (val != null) {
                              final price = CategoryHelpers.commonBeauticianServices[val];
                              if (price != null) {
                                priceCtrl.text = price.toStringAsFixed(0);
                              }
                            }
                          });
                        },
                      )
                    else if (_isSecurity)
                      DropdownButtonFormField<String>(
                        value: selectedTestName,
                        decoration: const InputDecoration(
                          labelText: 'Service Name *',
                          border: OutlineInputBorder(),
                        ),
                        items: CategoryHelpers.commonSecurityServiceNames
                            .map((test) => DropdownMenuItem(
                                  value: test,
                                  child: Text(test),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedTestName = val;
                            nameCtrl.text = val ?? '';
                            if (val != null) {
                              final price = CategoryHelpers.commonSecurityServices[val];
                              if (price != null) {
                                priceCtrl.text = price.toStringAsFixed(0);
                              }
                            }
                          });
                        },
                      )
                    else
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Service Name *',
                          hintText: 'e.g. Haircut, Shave',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Price *',
                        prefixText: '₹',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes)',
                        suffixText: 'mins',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Update name controller from dropdown if needed (though we did it in onChanged)
                    if ((_isBloodTechnician || _isNapit || _isBeautician || _isSecurity) && selectedTestName != null) {
                       nameCtrl.text = selectedTestName!;
                    }

                    if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Name and Price are required'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final service = ServiceItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text.trim(),
                      price: double.tryParse(priceCtrl.text) ?? 0.0,
                      description: descCtrl.text.trim(),
                      duration: int.tryParse(durationCtrl.text) ?? 30,
                    );

                    // We need to call setState of the parent widget
                    // But since we are in a dialog, we need to call the callback
                    // Wait, _services.add(service) modifies the local state of _ServicesListManagerState
                    // But we are in a dialog...
                    // The dialog is pushing a new route.
                    // Effectively, when we click "Add", we close the dialog and update the parent state.
                    
                    Navigator.pop(context); // Close dialog first

                    // Then update parent state
                    if (mounted) {
                      this.setState(() {
                        _services.add(service);
                        widget.onServicesChanged(_services);
                      });
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _editService(int index) {
    final service = _services[index];
    final nameCtrl = TextEditingController(text: service.name);
    final priceCtrl = TextEditingController(text: service.price.toString());
    final descCtrl = TextEditingController(text: service.description);
    final durationCtrl = TextEditingController(text: service.duration.toString());

    String? selectedTestName = (_isBloodTechnician || _isNapit || _isBeautician || _isSecurity) ? service.name : null;
    
    if (_isBloodTechnician && !CategoryHelpers.commonBloodTests.contains(selectedTestName)) {
        if (CategoryHelpers.commonBloodTests.contains(nameCtrl.text)) {
           selectedTestName = nameCtrl.text;
        } else {
           selectedTestName = null; 
        }
    } else if (_isNapit && !CategoryHelpers.commonNapitServiceNames.contains(selectedTestName)) {
        if (CategoryHelpers.commonNapitServiceNames.contains(nameCtrl.text)) {
           selectedTestName = nameCtrl.text;
        } else {
           selectedTestName = null; 
        }
    } else if (_isBeautician && !CategoryHelpers.commonBeauticianServiceNames.contains(selectedTestName)) {
        if (CategoryHelpers.commonBeauticianServiceNames.contains(nameCtrl.text)) {
           selectedTestName = nameCtrl.text;
        } else {
           selectedTestName = null; 
        }
    } else if (_isSecurity && !CategoryHelpers.commonSecurityServiceNames.contains(selectedTestName)) {
        if (CategoryHelpers.commonSecurityServiceNames.contains(nameCtrl.text)) {
           selectedTestName = nameCtrl.text;
        } else {
           selectedTestName = null; 
        }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) { 
            return AlertDialog(
              title: const Text('Edit Service'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isBloodTechnician)
                      DropdownButtonFormField<String>(
                        value: selectedTestName,
                        decoration: const InputDecoration(
                          labelText: 'Service Name *',
                          border: OutlineInputBorder(),
                        ),
                        items: CategoryHelpers.commonBloodTests
                            .map((test) => DropdownMenuItem(
                                  value: test,
                                  child: Text(test),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedTestName = val;
                            nameCtrl.text = val ?? '';
                            if (val != null) {
                              final price = CategoryHelpers.commonBloodTestPrices[val];
                              if (price != null) {
                                priceCtrl.text = price.toStringAsFixed(0);
                              }
                            }
                          });
                        },
                      )
                    else if (_isNapit)
                      DropdownButtonFormField<String>(
                        value: selectedTestName,
                        decoration: const InputDecoration(
                          labelText: 'Service Name *',
                          border: OutlineInputBorder(),
                        ),
                        items: CategoryHelpers.commonNapitServiceNames
                            .map((test) => DropdownMenuItem(
                                  value: test,
                                  child: Text(test),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedTestName = val;
                            nameCtrl.text = val ?? '';
                            if (val != null) {
                              final price = CategoryHelpers.commonNapitServices[val];
                              if (price != null) {
                                priceCtrl.text = price.toStringAsFixed(0);
                              }
                            }
                          });
                        },
                      )
                    else if (_isBeautician)
                      DropdownButtonFormField<String>(
                        value: selectedTestName,
                        decoration: const InputDecoration(
                          labelText: 'Service Name *',
                          border: OutlineInputBorder(),
                        ),
                        items: CategoryHelpers.commonBeauticianServiceNames
                            .map((test) => DropdownMenuItem(
                                  value: test,
                                  child: Text(test),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedTestName = val;
                            nameCtrl.text = val ?? '';
                            if (val != null) {
                              final price = CategoryHelpers.commonBeauticianServices[val];
                              if (price != null) {
                                priceCtrl.text = price.toStringAsFixed(0);
                              }
                            }
                          });
                        },
                      )
                    else if (_isSecurity)
                      DropdownButtonFormField<String>(
                        value: selectedTestName,
                        decoration: const InputDecoration(
                          labelText: 'Service Name *',
                          border: OutlineInputBorder(),
                        ),
                        items: CategoryHelpers.commonSecurityServiceNames
                            .map((test) => DropdownMenuItem(
                                  value: test,
                                  child: Text(test),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedTestName = val;
                            nameCtrl.text = val ?? '';
                            if (val != null) {
                              final price = CategoryHelpers.commonSecurityServices[val];
                              if (price != null) {
                                priceCtrl.text = price.toStringAsFixed(0);
                              }
                            }
                          });
                        },
                      )
                    else 
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Service Name *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Price *',
                        prefixText: '₹',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes)',
                        suffixText: 'mins',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Name and Price are required'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Update parent state
                    this.setState(() {
                      _services[index] = ServiceItem(
                        id: service.id,
                        name: nameCtrl.text.trim(),
                        price: double.tryParse(priceCtrl.text) ?? 0.0,
                        description: descCtrl.text.trim(),
                        duration: int.tryParse(durationCtrl.text) ?? 30,
                      );
                      widget.onServicesChanged(_services);
                    });

                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _deleteService(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Are you sure you want to delete "${_services[index].name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _services.removeAt(index);
                widget.onServicesChanged(_services);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Services List',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _addService,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Service'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_services.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No services added yet. Click "Add Service" to start.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final service = _services[index];
              final earnings = service.price * (1 - (widget.platformFeePercentage / 100));
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Icon(
                          Icons.content_cut,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${service.price.toStringAsFixed(0)} • ${service.duration} mins',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your Earnings: ₹${earnings.toStringAsFixed(2)} (After ${widget.platformFeePercentage.toStringAsFixed(0)}% fee)',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _editService(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => _deleteService(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
