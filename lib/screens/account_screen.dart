import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/auth_provider.dart';
import 'auth_screen.dart';
import 'edit_profile_screen.dart';
import 'admin_panel_screen.dart';
import 'seller_dashboard_screen.dart';
import 'service_provider_dashboard_screen.dart';
import 'service_provider_dashboard_screen.dart';
import 'core_staff_dashboard_screen.dart';
import 'store_manager_dashboard_screen.dart';
import 'join_partner_screen.dart';
import 'static_pages.dart';

class AccountScreen extends StatefulWidget {
  static const routeName = '/account';
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Widget _buildNetworkAvatar(
    String imageUrl,
    String fallbackInitial,
    BuildContext context,
  ) {
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 100,
            height: 100,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Center(
              child: Text(
                fallbackInitial,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          final progress =
              loadingProgress.cumulativeBytesLoaded /
              (loadingProgress.expectedTotalBytes ?? 1);
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? progress
                  : null,
              strokeWidth: 2,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        return Scaffold(
          appBar: AppBar(title: const Text('My Profile'), elevation: 0),
          body: auth.isLoggedIn
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header with gradient
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primaryContainer,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            // Avatar with error handling
                            CircleAvatar(
                              radius: 50,
                              key: ValueKey(auth.currentUser!.photoURL),
                              backgroundColor: Colors.white,
                              child: auth.currentUser!.photoURL != null
                                  ? _buildNetworkAvatar(
                                      auth.currentUser!.photoURL!,
                                      auth.currentUser!.name.isNotEmpty
                                          ? auth.currentUser!.name[0]
                                                .toUpperCase()
                                          : 'U',
                                      context,
                                    )
                                  : Text(
                                      auth.currentUser!.name.isNotEmpty
                                          ? auth.currentUser!.name[0]
                                                .toUpperCase()
                                          : 'U',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              auth.currentUser!.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              auth.currentUser!.email,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            if (auth.currentUser!.phoneNumber != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                auth.currentUser!.phoneNumber!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Pending Partner Request Banner (Hindi)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('partner_requests')
                              .where(
                                'email',
                                isEqualTo: auth.currentUser!.email,
                              )
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }
                            if (snapshot.hasError || !snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final docs = snapshot.data!.docs;
                            if (docs.isEmpty) return const SizedBox.shrink();

                            // Check if any request is still pending
                            final hasPending = docs.any((d) {
                              final data = d.data() as Map<String, dynamic>;
                              return (data['status'] ?? 'pending') == 'pending';
                            });

                            if (!hasPending) return const SizedBox.shrink();

                            return Card(
                              color: Colors.orange.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.shade100,
                                  child: const Icon(
                                    Icons.hourglass_top,
                                    color: Colors.orange,
                                  ),
                                ),
                                title: const Text(
                                  'Partner Request Pending',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Aapka Partner Request abhi pending hai. Kripya approval ka intezaar karein. ✅',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Profile Options
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // 1. MOST IMPORTANT - Edit Profile (Short, Frequently Used)
                            _buildProfileCard(
                              context: context,
                              icon: Icons.person_outline,
                              title: 'Edit Profile',
                              subtitle: 'Update your details',
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  EditProfileScreen.routeName,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            
                            // 2. My Orders (Short, Frequently Used)
                            _buildProfileCard(
                              context: context,
                              icon: Icons.shopping_bag_outlined,
                              title: 'My Orders',
                              subtitle: 'Order history',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/my-orders'),
                            ),
                            const SizedBox(height: 12),

                            // 2A. My Bookings (New Feature)
                             _buildProfileCard(
                              context: context,
                              icon: Icons.calendar_today_outlined,
                              title: 'My Bookings',
                              subtitle: 'Service appointments',
                              onTap: () => Navigator.pushNamed(context, '/my-bookings'),
                            ),
                            const SizedBox(height: 12),

                            // 3. DASHBOARDS - Role-based (Medium Priority)
                            // Service Provider Dashboard
                            if (auth.currentUser?.role == 'service_provider')
                              Column(
                                children: [
                                  _buildProfileCard(
                                    context: context,
                                    icon: Icons.work_outline,
                                    title: 'My Dashboard',
                                    subtitle: 'Service requests',
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        ServiceProviderDashboardScreen
                                            .routeName,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // Seller Dashboard
                            if (auth.currentUser?.role == 'seller')
                              Column(
                                children: [
                                  _buildProfileCard(
                                    context: context,
                                    icon: Icons.dashboard,
                                    title: 'My Dashboard',
                                    subtitle: 'Products & sales',
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        SellerDashboardScreen.routeName,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // Core Staff Dashboard
                            if (auth.isCoreStaff)
                              Column(
                                children: [
                                  _buildProfileCard(
                                    context: context,
                                    icon: Icons.people_alt_outlined,
                                    title: 'My Dashboard',
                                    subtitle: 'Core operations',
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        CoreStaffDashboardScreen.routeName,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // State Admin Dashboard
                            if (auth.isStateAdmin)
                              Column(
                                children: [
                                  _buildProfileCard(
                                    context: context,
                                    icon: Icons.business,
                                    title: 'My Dashboard',
                                    subtitle: 'State operations',
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        AdminPanelScreen.routeName,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // Administrator Dashboard
                            if (auth.isAdministrator)
                              Column(
                                children: [
                                  _buildProfileCard(
                                    context: context,
                                    icon: Icons.admin_panel_settings,
                                    title: 'My Dashboard',
                                    subtitle: 'System admin',
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        AdminPanelScreen.routeName,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // Store Manager Dashboard
                            if (auth.isStoreManager)
                              Column(
                                children: [
                                  _buildProfileCard(
                                    context: context,
                                    icon: Icons.store_outlined,
                                    title: 'My Dashboard',
                                    subtitle: 'Store inventory',
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        StoreManagerDashboardScreen.routeName,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // Manager Dashboard
                            if (auth.isManager)
                              Column(
                                children: [
                                  _buildProfileCard(
                                    context: context,
                                    icon: Icons.manage_accounts_outlined,
                                    title: 'My Dashboard',
                                    subtitle: 'Team operations',
                                    onTap: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Manager Dashboard - Coming Soon',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // Delivery Partner Dashboard
                            if (auth.isDeliveryPartner)
                              Column(
                                children: [
                                  _buildProfileCard(
                                    context: context,
                                    icon: Icons.delivery_dining_outlined,
                                    title: 'My Dashboard',
                                    subtitle: 'Your deliveries',
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/delivery-dashboard',
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // Customer Care Dashboard
                            if (auth.isCustomerCare)
                              Column(
                                children: [
                                  _buildProfileCard(
                                    context: context,
                                    icon: Icons.support_agent_outlined,
                                    title: 'My Dashboard',
                                    subtitle: 'Customer queries',
                                    onTap: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Customer Care Dashboard - Coming Soon',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // Admin Panel (legacy)
                            if (auth.isAdmin && !auth.isAdministrator)
                              Column(
                                children: [
                                  _buildProfileCard(
                                    context: context,
                                    icon: Icons.admin_panel_settings,
                                    title: 'My Dashboard',
                                    subtitle: 'Products & inventory',
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        AdminPanelScreen.routeName,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // 4. Email (Info Only - Medium Priority)
                            _buildProfileCard(
                              context: context,
                              icon: Icons.email_outlined,
                              title: 'Email',
                              subtitle: auth.currentUser!.email,
                              onTap: null,
                            ),
                            const SizedBox(height: 12),

                            // 5. GENERAL INFO - Lower Priority
                            _buildProfileCard(
                              context: context,
                              icon: Icons.info_outline,
                              title: 'About Us',
                              subtitle: 'Learn about Dimandy',
                              onTap: () => Navigator.pushNamed(context, AboutScreen.routeName),
                            ),
                            const SizedBox(height: 12),
                            
                            _buildProfileCard(
                              context: context,
                              icon: Icons.contact_support_outlined,
                              title: 'Contact Us',
                              subtitle: 'Help & support',
                              onTap: () => Navigator.pushNamed(context, ContactScreen.routeName),
                            ),
                            const SizedBox(height: 12),
                            
                            // 6. LEAST PRIORITY - Partner Signup (Only for regular users)
                            if (auth.currentUser?.role == 'user')
                               _buildProfileCard(
                                context: context,
                                icon: Icons.storefront,
                                title: 'Become a Partner',
                                subtitle: 'Sell on Dimandy',
                                onTap: () => Navigator.pushNamed(context, JoinPartnerScreen.routeName),
                              ),

                            const SizedBox(height: 20),
                            const SizedBox(height: 20),
                            // Sign Out Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Sign Out'),
                                      content: const Text(
                                        'Are you sure you want to sign out?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Sign Out'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && mounted) {
                                    await context
                                        .read<AuthProvider>()
                                        .signOut();
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Signed out successfully',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.logout),
                                label: const Text('Sign Out'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Request Account Deletion logic
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Account'),
                                      content: const Text(
                                        'Are you sure you want to request account deletion? Your data will be permanently removed within 30 days. This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true && mounted) {
                                    try {
                                      // 1. Submit deletion request
                                      await FirebaseFirestore.instance
                                          .collection('deletion_requests')
                                          .add({
                                        'userId': auth.currentUser!.uid,
                                        'email': auth.currentUser!.email,
                                        'reason': 'User requested via app',
                                        'requestedAt': FieldValue.serverTimestamp(),
                                        'status': 'pending',
                                      });

                                      // 2. Sign Out
                                      if (mounted) {
                                        await context.read<AuthProvider>().signOut();
                                        
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Deletion request submitted. You have been signed out.',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          // Navigation to AuthScreen is handled by AuthWrapper usually, 
                                          // but ensuring we pop any dialogs or screens if needed.
                                          Navigator.of(context).popUntil((route) => route.isFirst);
                                        }
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Request Account Deletion'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 80), // Increased safe area padding
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_circle_outlined,
                            size: 100,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'You are not signed in',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to access your profile, orders, and more',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, AuthScreen.routeName);
                            },
                            icon: const Icon(Icons.login),
                            label: const Text('Sign In / Sign Up'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Footer Links for SEO
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: [
                              TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, JoinPartnerScreen.routeName),
                                  child: const Text('Join as Partner')),
                              TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, AboutScreen.routeName),
                                  child: const Text('About Us')),
                              TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, ContactScreen.routeName),
                                  child: const Text('Contact Us')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildProfileCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }
}
