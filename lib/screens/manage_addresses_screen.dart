import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/address_provider.dart';
import '../models/address_model.dart';

class ManageAddressesScreen extends StatefulWidget {
  static const routeName = '/manage-addresses';

  const ManageAddressesScreen({super.key});

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AddressProvider>().fetch());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Addresses'),
      ),
      body: Consumer<AddressProvider>(
        builder: (context, addressProvider, child) {
          if (addressProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (addressProvider.addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No addresses saved yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _openEditAddressDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Address'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: addressProvider.addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final address = addressProvider.addresses[index];
              return Card(
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(
                    address.isDefault ? Icons.star : Icons.location_on,
                    color: address.isDefault ? Colors.amber : Colors.grey,
                    size: 32,
                  ),
                  title: Text(
                    address.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(address.phone),
                      const SizedBox(height: 4),
                      Text(
                        '${address.addressLine}, ${address.city} - ${address.postalCode}',
                        style: const TextStyle(height: 1.3),
                      ),
                      if (address.isDefault)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _openEditAddressDialog(existing: address);
                      } else if (value == 'delete') {
                        await _confirmDelete(address);
                      } else if (value == 'default') {
                        await addressProvider.setDefault(address.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      if (!address.isDefault)
                        const PopupMenuItem(
                          value: 'default',
                          child: Row(
                            children: [
                              Icon(Icons.star_border, size: 20),
                              SizedBox(width: 8),
                              Text('Set as Default'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditAddressDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(Address address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AddressProvider>().delete(address.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address deleted')),
        );
      }
    }
  }

  Future<void> _openEditAddressDialog({Address? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.fullName);
    final phoneCtrl = TextEditingController(text: existing?.phone);
    final lineCtrl = TextEditingController(text: existing?.addressLine);
    final cityCtrl = TextEditingController(text: existing?.city);
    final pinCtrl = TextEditingController(text: existing?.postalCode);
    bool isDefault = existing?.isDefault ?? false;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Add Address' : 'Edit Address'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  maxLength: 10,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter phone number';
                    if (v.length != 10) return 'Phone number must be 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lineCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address (House No, Street)',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: cityCtrl,
                        decoration: const InputDecoration(labelText: 'City'),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: pinCtrl,
                        decoration: const InputDecoration(labelText: 'PIN Code'),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (context, setInner) {
                    return CheckboxListTile(
                      value: isDefault,
                      onChanged: (v) => setInner(() => isDefault = v ?? false),
                      title: const Text('Set as default address'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              
              final provider = context.read<AddressProvider>();
              try {
                if (existing == null) {
                  await provider.add(
                    Address(
                      id: '',
                      fullName: nameCtrl.text,
                      phone: phoneCtrl.text,
                      addressLine: lineCtrl.text,
                      city: cityCtrl.text,
                      postalCode: pinCtrl.text,
                      isDefault: isDefault,
                    ),
                  );
                } else {
                  await provider.update(
                    Address(
                      id: existing.id,
                      fullName: nameCtrl.text,
                      phone: phoneCtrl.text,
                      addressLine: lineCtrl.text,
                      city: cityCtrl.text,
                      postalCode: pinCtrl.text,
                      isDefault: isDefault,
                    ),
                  );
                }
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        existing == null
                            ? 'Address added successfully'
                            : 'Address updated successfully',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
