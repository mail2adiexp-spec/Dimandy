import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PermissionEditorScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userRole;
  final Map<String, dynamic> currentPermissions;

  const PermissionEditorScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.currentPermissions,
  });

  @override
  State<PermissionEditorScreen> createState() => _PermissionEditorScreenState();
}

class _PermissionEditorScreenState extends State<PermissionEditorScreen> {
  late Map<String, dynamic> tempPermissions;
  Map<String, Map<String, String>> permissionSections = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    tempPermissions = Map.of(widget.currentPermissions);
    _loadPermissionSections();
  }

  void _loadPermissionSections() {
    // Reset
    permissionSections = {};

    if (widget.userRole == 'seller') {
      permissionSections['Product Management'] = {
        'can_add_product': 'Add New Products',
        'can_edit_product': 'Edit Products',
        'can_delete_product': 'Delete Products',
        'can_upload_product_images': 'Upload Product Images',
        'can_manage_inventory': 'Manage Inventory/Stock',
        'can_set_prices': 'Set Product Prices',
        'can_set_discounts': 'Set Discounts/Offers',
      };
      permissionSections['Order Management'] = {
        'can_view_orders': 'View Orders',
        'can_update_order_status': 'Update Order Status',
        'can_cancel_orders': 'Cancel Orders',
        'can_process_refunds': 'Process Refunds', // Added back
      };
      permissionSections['Analytics & Reports'] = {
        'can_view_analytics': 'View Sales Analytics',
        'can_view_reports': 'View Sales Reports',
        'can_export_data': 'Export Data',
      };
      permissionSections['Customer Interaction'] = {
        'can_view_reviews': 'View Customer Reviews',
        'can_respond_reviews': 'Respond to Reviews',
        'can_contact_customers': 'Contact Customers',
      };
    } else if (widget.userRole == 'service_provider') {
      permissionSections['Service Management'] = {
        'can_add_service': 'Add New Services',
        'can_edit_service': 'Edit Services',
        'can_delete_service': 'Delete Services',
        'can_upload_service_images': 'Upload Service Images',
        'can_set_service_pricing': 'Set Service Pricing',
        'can_set_service_area': 'Set Service Area/Location',
      };
      permissionSections['Service Requests'] = {
        'can_view_requests': 'View Service Requests',
        'can_accept_requests': 'Accept Service Requests',
        'can_reject_requests': 'Reject Service Requests',
        'can_update_service_status': 'Update Service Status',
        'can_complete_service': 'Mark Service as Completed',
        'can_cancel_service': 'Cancel Service',
      };
      permissionSections['Schedule & Availability'] = {
        'can_manage_schedule': 'Manage Work Schedule',
        'can_set_availability': 'Set Availability Status',
      };
      permissionSections['Analytics & Customer'] = {
        'can_view_service_analytics': 'View Service Analytics',
        'can_view_ratings': 'View Customer Ratings',
        'can_respond_ratings': 'Respond to Ratings',
        'can_view_earnings': 'View Earnings',
      };
    } else if (widget.userRole == 'delivery_partner') {
      permissionSections['Delivery Management'] = {
        'can_view_deliveries': 'View Assigned Deliveries',
        'can_accept_delivery': 'Accept Delivery Requests',
        'can_reject_delivery': 'Reject Delivery Requests',
      };
      permissionSections['Status Updates'] = {
        'can_mark_picked': 'Mark as Picked Up',
        'can_mark_in_transit': 'Mark as In Transit',
        'can_mark_delivered': 'Mark as Delivered',
        'can_update_location': 'Update Current Location',
      };
      permissionSections['Order & Customer'] = {
        'can_view_order_details': 'View Order Details',
        'can_contact_customer': 'Contact Customer',
        'can_contact_seller': 'Contact Seller',
        'can_report_issue': 'Report Delivery Issues',
      };
      permissionSections['Availability & Earnings'] = {
        'can_set_availability': 'Set Availability Status',
        'can_view_delivery_history': 'View Delivery History',
        'can_view_earnings': 'View Earnings',
        'can_view_analytics': 'View Delivery Analytics',
      };
    } else if (widget.userRole == 'core_staff') {
      permissionSections['General Management'] = {
        'can_view_dashboard': 'View Dashboard',
        'can_manage_users': 'Manage Users',
        'can_manage_permissions': 'Manage Permissions',
      };
      permissionSections['Marketplace Operations'] = {
        'can_manage_products': 'Manage All Products',
        'can_manage_orders': 'Manage All Orders',
        'can_manage_categories': 'Manage Categories',
        'can_manage_service_categories': 'Manage Service Categories',
        'can_manage_featured': 'Manage Featured Sections',
        'can_manage_gifts': 'Manage Gifts',
      };
      permissionSections['Partner Management'] = {
        'can_manage_sellers': 'Manage Sellers',
        'can_manage_services': 'Manage Services',
        'can_manage_service_providers': 'Manage Service Providers',
        'can_manage_deliveries': 'Manage Delivery Partners',
        'can_manage_stores': 'Manage Stores',
        'can_manage_partners': 'Manage Partner Requests',
      };
      permissionSections['Financial'] = {
        'can_manage_payouts': 'Manage Payout Requests',
        'can_manage_refunds': 'Manage Refunds',
      };
    } else if (widget.userRole == 'store_manager') {
      permissionSections['Store Operations'] = {
        'can_view_store_dashboard': 'View Store Dashboard',
        'can_edit_store_settings': 'Edit Store Information',
        'can_manage_store_products': 'Manage Store Products',
        'can_manage_store_orders': 'Manage Store Orders',
      };
      permissionSections['Reports'] = {
        'can_download_reports': 'Download Reports',
        'can_view_analytics': 'View Store Analytics',
      };
    } else if (widget.userRole == 'administrator') {
      permissionSections['Full Access'] = {
        'can_manage_permissions': 'Manage Permissions',
        'can_manage_products': 'Manage Products',
        'can_manage_orders': 'Manage Orders',
        'can_manage_users': 'Manage Users',
        'can_manage_stores': 'Manage Stores',
        'can_manage_payouts': 'Manage Payouts',
        'can_manage_refunds': 'Manage Refunds',
        'can_view_dashboard': 'View Dashboard',
        // Add all others implicitly or explicitly
      };
      // Admins typically have all, but list some just in case granular control is needed
    }
    
    // Check for "Custom" permissions (keys present in tempPermissions but not in sections)
    _identifyCustomPermissions();
  }

  void _identifyCustomPermissions() {
    // Collect all defined keys
    final Set<String> definedKeys = {};
    for (var section in permissionSections.values) {
      definedKeys.addAll(section.keys);
    }

    // Find extras
    final Map<String, String> extras = {};
    tempPermissions.forEach((key, value) {
      if (!definedKeys.contains(key)) {
        extras[key] = key; // Use key as label
      }
    });

    if (extras.isNotEmpty) {
      permissionSections['Custom / Extra Config'] = extras;
    }
  }

  Future<void> _savePermissions() async {
    setState(() => isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'permissions': tempPermissions});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => isLoading = false);
      }
    }
  }

  void _addCustomPermission(String sectionName) {
    final keyCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Custom Permission to "$sectionName"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(labelText: 'Permission Key (e.g. can_do_magic)', prefixText: 'can_'),
            ),
            // Checkbox for value? Default true.
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final keyRaw = keyCtrl.text.trim();
              if (keyRaw.isNotEmpty) {
                final key = keyRaw.startsWith('can_') ? keyRaw : 'can_$keyRaw';
                setState(() {
                  tempPermissions[key] = true;
                  // Add to section for UI consistency in this session
                  if (!permissionSections.containsKey(sectionName)) {
                     permissionSections[sectionName] = {};
                  }
                  permissionSections[sectionName]![key] = key; // Label is key
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Permissions: ${widget.userName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: isLoading ? null : _savePermissions,
          ),
        ],
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Increased bottom padding
                children: [
                if (permissionSections.isEmpty)
                   const Center(child: Padding(
                     padding: EdgeInsets.all(24.0),
                     child: Text('No predefined permissions for this role. Add Custom ones?'),
                   )),

                ...permissionSections.entries.map((sectionEntry) {
                  final sectionTitle = sectionEntry.key;
                  final permissionsMap = sectionEntry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(sectionTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                      children: [
                        ...permissionsMap.entries.map((permEntry) {
                          final key = permEntry.key;
                          final label = permEntry.value;
                          final isEnabled = tempPermissions[key] ?? false; // Default false if missing

                          return SwitchListTile(
                            title: Text(label),
                            subtitle: Text(key, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            value: isEnabled == true, // Strict check
                            onChanged: (val) {
                              setState(() {
                                tempPermissions[key] = val;
                              });
                            },
                          );
                        }),
                        ListTile(
                          leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
                          title: const Text('Add Custom Permission', style: TextStyle(color: Colors.blue)),
                          onTap: () => _addCustomPermission(sectionTitle),
                        ),
                      ],
                    ),
                  );
                }),
                
                // Final "Add New Section" button?
                OutlinedButton.icon(
                  onPressed: () {
                     _addCustomPermission("Custom / Extra Config");
                  }, 
                  icon: const Icon(Icons.playlist_add), 
                  label: const Text('Add Custom Permission (Global)'),
                ),
              ],
            ),
          ),
    );
  }
}
