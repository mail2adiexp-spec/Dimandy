import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/admin_panel_screen.dart';

class AdminPanelGuard extends StatelessWidget {
  const AdminPanelGuard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: true);

    // Not logged in: show Auth screen
    if (!auth.isLoggedIn) {
      return const AuthScreen();
    }

    // Logged in but not admin: block access
    if (!auth.hasAdminAccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied: Admins only'),
            backgroundColor: Colors.red,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });

      return Scaffold(
        appBar: AppBar(title: const Text('Admin Panel')),
        body: const Center(child: Text('Access denied: Admins only')),
      );
    }

    // Admin: proceed
    return const AdminPanelScreen();
  }
}
