import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'admin_panel_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  static const routeName = '/staff-dashboard';
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final userRole = user?.role ?? 'user';

    if (user == null || userRole != 'core_staff') {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff Dashboard')),
        body: const Center(child: Text('Access denied: Staff only')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Staff Dashboard'), elevation: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.purple,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'S',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
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
                            'Welcome, ${user.name}!',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Core Staff Member',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Permissions Summary
            Text(
              'Your Permissions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            user.permissions.values
                                .where((v) => v == true)
                                .length
                                .toString(),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 60,
                      width: 1,
                      color: Colors.grey[300],
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.lock_outline,
                              color: Colors.orange, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            '21',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.dashboard, color: Colors.white),
                    ),
                    title: const Text('Admin Panel'),
                    subtitle: const Text('Access admin panel features'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.of(context)
                          .pushNamed(AdminPanelScreen.routeName);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.inventory, color: Colors.white),
                    ),
                    title: const Text('Manage Products'),
                    subtitle: const Text('View and edit products'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (user.hasPermission('can_manage_products')) {
                        Navigator.of(context)
                            .pushNamed(AdminPanelScreen.routeName);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Navigate to Admin Panel → Products'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Access Denied: You do not have permission to manage products.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.shopping_cart, color: Colors.white),
                    ),
                    title: const Text('Manage Orders'),
                    subtitle: const Text('View and process orders'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (user.hasPermission('can_manage_orders')) {
                        Navigator.of(context)
                            .pushNamed(AdminPanelScreen.routeName);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Navigate to Admin Panel → Orders'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Access Denied: You do not have permission to manage orders.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.purple,
                      child: Icon(Icons.people, color: Colors.white),
                    ),
                    title: const Text('Manage Users'),
                    subtitle: const Text('View and manage users'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (user.hasPermission('can_manage_users')) {
                        Navigator.of(context)
                            .pushNamed(AdminPanelScreen.routeName);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Navigate to Admin Panel → Users'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Access Denied: You do not have permission to manage users.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.analytics, color: Colors.white),
                    ),
                    title: const Text('Analytics'),
                    subtitle: const Text('View analytics dashboard'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (user.hasPermission('can_view_analytics')) {
                        Navigator.of(context)
                            .pushNamed(AdminPanelScreen.routeName);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Navigate to Admin Panel → Analytics'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Access Denied: You do not have permission to view analytics.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Active Permissions List
            Text(
              'Active Permissions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: (user.permissions.isEmpty ||
                      user.permissions.values.every((v) => v != true))
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No permissions assigned yet',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Contact administrator to assign permissions',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: user.permissions.entries
                            .where((e) => e.value == true)
                            .map(
                              (e) => Chip(
                                avatar: Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Colors.purple.shade700,
                                ),
                                label: Text(
                                  _formatPermissionName(e.key),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: Colors.purple.shade50,
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPermissionName(String permKey) {
    // Convert can_manage_products to "Manage Products"
    return permKey
        .replaceAll('can_', '')
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
