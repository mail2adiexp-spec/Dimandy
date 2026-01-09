import 'dart:io';

void main() async {
  final file = File('lib/screens/core_staff_dashboard_screen.dart');
  final lines = await file.readAsLines();

  // 1. Update _setupTabs
  int setupStart = -1;
  int setupEnd = -1;
  
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('void _setupTabs() {')) {
      setupStart = i;
      break;
    }
  }
  
  if (setupStart != -1) {
    int openBraces = 0;
    for (int i = setupStart; i < lines.length; i++) {
      openBraces += lines[i].allMatches('{').length;
      openBraces -= lines[i].allMatches('}').length;
      if (openBraces == 0) {
        setupEnd = i;
        break;
      }
    }
  }

  if (setupStart != -1 && setupEnd != -1) {
    final newSetup = [
      '  void _setupTabs() {',
      '    _tabs = [];',
      '    _tabViews = [];',
      '',
      '    // Always add Dashboard Home',
      '    _tabs.add(const Tab(icon: Icon(Icons.dashboard), text: \'Dashboard\'));',
      '    _tabViews.add(_buildDashboardHome());',
      '    ',
      '    // Trigger metrics fetch',
      '    _fetchDashboardMetrics();',
      '',
      '    if (_permissionChecker?.canViewProducts == true) {',
      '      _tabs.add(const Tab(icon: Icon(Icons.inventory), text: \'Products\'));',
      '      _tabViews.add(SharedProductsTab(',
      '        canManage: _permissionChecker?.canManageProducts ?? false,',
      '      ));',
      '    }',
      '',
      '    if (_permissionChecker?.canViewOrders == true) {',
      '      _tabs.add(const Tab(icon: Icon(Icons.shopping_bag), text: \'Orders\'));',
      '      _tabViews.add(SharedOrdersTab(',
      '        canManage: _permissionChecker?.canManageOrders ?? false,',
      '      ));',
      '    }',
      '    ',
      '    if (_permissionChecker?.canViewUsers == true) {',
      '      _tabs.add(const Tab(icon: Icon(Icons.people), text: \'Users\'));',
      '      _tabViews.add(SharedUsersTab(',
      '        canManage: _permissionChecker?.canManageUsers ?? false,',
      '      ));',
      '    }',
      '',
      '    if (_permissionChecker?.canViewServices == true) {',
      '      _tabs.add(const Tab(icon: Icon(Icons.handyman), text: \'Services\'));',
      '      _tabViews.add(SharedServicesTab(',
      '        canManage: _permissionChecker?.canManageServices ?? false,',
      '      ));',
      '    }',
      '    ',
      '    if (_permissionChecker?.canManagePartners == true) {',
      '       // Partners Tab Group',
      '       _tabs.add(const Tab(icon: Icon(Icons.group_add), text: \'Requests\'));',
      '       _tabViews.add(_buildPartnerRequestsTab());',
      '       ',
      '       _tabs.add(const Tab(icon: Icon(Icons.store), text: \'Sellers\'));',
      '       _tabViews.add(_buildRoleBasedUsersTab(\'seller\'));',
      '       ',
      '       _tabs.add(const Tab(icon: Icon(Icons.local_shipping), text: \'Delivery\'));',
      '       _tabViews.add(_buildRoleBasedUsersTab(\'delivery_partner\'));',
      '    }',
      '',
      '    _tabController = TabController(length: _tabs.length, vsync: this);',
      '  }'
    ];
    lines.removeRange(setupStart, setupEnd + 1);
    lines.insertAll(setupStart, newSetup);
  }

  // 2. Update _buildDashboardHome to use metrics
  // We'll simplisticly replace 'value: \'Loading...\'' with specific keys
  // but regex replacement is safer on lines.
  // Actually, I can just append the logic at the end and manually refactor _buildDashboardHome later? 
  // No, script is better.
  
  // Find _buildDashboardHome
   int dashStart = -1;
   int dashEnd = -1;
   for(int i=0; i<lines.length; i++) {
     if (lines[i].contains('Widget _buildDashboardHome() {')) {
       dashStart = i;
       break;
     }
   }
   
   // ... finding end ...
   if (dashStart != -1) {
      int openBraces = 0;
      for (int i = dashStart; i < lines.length; i++) {
        openBraces += lines[i].allMatches('{').length;
        openBraces -= lines[i].allMatches('}').length;
        if (openBraces == 0) {
          dashEnd = i;
          break;
        }
      }
      
      // We will replace the whole method to use _metrics
      final newDash = [
        '  Widget _buildDashboardHome() {',
        '    return SingleChildScrollView(',
        '      padding: const EdgeInsets.all(16),',
        '      child: Column(',
        '        crossAxisAlignment: CrossAxisAlignment.start,',
        '        children: [',
        '          Text(',
        '            \'Welcome, Staff Member\',',
        '            style: Theme.of(context).textTheme.headlineSmall,',
        '          ),',
        '          const SizedBox(height: 24),',
        '          GridView.count(',
        '            shrinkWrap: true,',
        '            physics: const NeverScrollableScrollPhysics(),',
        '            crossAxisCount: 2,',
        '            crossAxisSpacing: 16,',
        '            mainAxisSpacing: 16,',
        '            children: [',
        '              _buildMetricCard(',
        '                title: \'Products\',',
        '                value: _metrics[\'products\'] ?? \'0\',',
        '                icon: Icons.inventory,',
        '                color: Colors.blue,',
        '              ),',
        '              _buildMetricCard(',
        '                title: \'Orders\',',
        '                value: _metrics[\'orders\'] ?? \'0\',',
        '                icon: Icons.shopping_cart,',
        '                color: Colors.orange,',
        '              ),',
        '              _buildMetricCard(',
        '                title: \'Users\',',
        '                value: _metrics[\'users\'] ?? \'0\',',
        '                icon: Icons.people,',
        '                color: Colors.green,',
        '              ),',
        '              _buildMetricCard(',
        '                title: \'Revenue\',',
        '                value: _metrics[\'revenue\'] ?? \'₹0\',',
        '                icon: Icons.currency_rupee,',
        '                color: Colors.purple,',
        '              ),',
        '            ],',
        '          ),',
        '        ],',
        '      ),',
        '    );',
        '  }'
      ];
      lines.removeRange(dashStart, dashEnd + 1);
      lines.insertAll(dashStart, newDash);
   }

  // 3. Append new methods at the end of class
  // Find last '}'
  int lastBrace = -1;
  for (int i = lines.length - 1; i >= 0; i--) {
    if (lines[i].trim() == '}') {
      lastBrace = i;
      break;
    }
  }

  if (lastBrace != -1) {
    final newMethods = [
      '',
      '  Future<void> _fetchDashboardMetrics() async {',
      '    try {',
      '       final products = await FirebaseFirestore.instance.collection(\'products\').count().get();',
      '       final orders = await FirebaseFirestore.instance.collection(\'orders\').count().get();',
      '       final users = await FirebaseFirestore.instance.collection(\'users\').where(\'role\', isEqualTo: \'user\').count().get();',
      '       // Revenue calculation is expensive, just mock or use specific document if available',
      '       // For now, simple count',
      '       setState(() {',
      '         _metrics[\'products\'] = products.count.toString();',
      '         _metrics[\'orders\'] = orders.count.toString();',
      '         _metrics[\'users\'] = users.count.toString();',
      '         _metrics[\'revenue\'] = \'--\'; // Requires aggregation',
      '       });',
      '    } catch (e) {',
      '       debugPrint(\'Error fetching metrics: \$e\');',
      '    }',
      '  }',
      '',
      '  Widget _buildPartnerRequestsTab() {',
      '    return RoleManagementTab(',
      '      key: const ValueKey(\'partner_requests\'),',
      '      collection: \'partner_requests\',',
      '      // role is n/a for requests collection usually, or we filter by something else',
      '      // In Admin Panel it is used without role filter for this collection',
      '      onEdit: (id, name, email, phone, role, pincode) {}, // Requests usually not editable like users',
      '      onDelete: (id, email) { _deleteRequest(id); },',
      '      onRequestAction: _updateRequestStatus,',
      '    );',
      '  }',
      '',
      '  Widget _buildRoleBasedUsersTab(String role) {',
      '    return RoleManagementTab(',
      '      collection: \'users\',',
      '      role: role,',
      '      requestRole: role == \'seller\' ? \'Seller\' : \'Delivery Partner\',',
      '      onEdit: _editUser,',
      '      onDelete: _deleteUser,',
      '      onRequestAction: _updateRequestStatus,',
      '      onViewDashboard: (id, data) {',
      '        // Simplified dashboard for core staff',
      '        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(\'Detailed dashboard available in Admin Panel\')));',
      '      },',
      '    );',
      '  }',
      '',
      '  Future<void> _updateRequestStatus(String id, String status) async {',
      '     try {',
      '       await FirebaseFirestore.instance.collection(\'partner_requests\').doc(id).update({\'status\': status});',
      '       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(\'Request \$status\')));',
      '     } catch (e) {',
      '       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(\'Error: \$e\')));',
      '     }',
      '  }',
      '',
      '  Future<void> _deleteRequest(String id) async {',
      '     try {',
      '       await FirebaseFirestore.instance.collection(\'partner_requests\').doc(id).delete();',
      '       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(\'Request deleted\')));',
      '     } catch (e) {',
      '       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(\'Error: \$e\')));',
      '     }',
      '  }',
      '',
      '  void _editUser(String userId, String name, String email, String phone, String role, String? servicePincode) {',
      '      // Use SharedUsersTab style dialog or similar. ',
      '      // For brevity, implementing simple edit dialog',
      '      final nameCtrl = TextEditingController(text: name);',
      '      final phoneCtrl = TextEditingController(text: phone);',
      '      final pincodeCtrl = TextEditingController(text: servicePincode ?? \'\');',
      '      showDialog(',
      '        context: context,',
      '        builder: (context) => AlertDialog(',
      '          title: const Text(\'Edit User\'),',
      '          content: Column(',
      '            mainAxisSize: MainAxisSize.min,',
      '            children: [',
      '              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: \'Name\')),',
      '              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: \'Phone\')),',
      '              if (role == \'delivery_partner\') TextField(controller: pincodeCtrl, decoration: const InputDecoration(labelText: \'Pincode\')),',
      '            ],',
      '          ),',
      '          actions: [',
      '             TextButton(onPressed: () => Navigator.pop(context), child: const Text(\'Cancel\')),',
      '             ElevatedButton(onPressed: () async {',
      '                 try {',
      '                   final updates = {\'name\': nameCtrl.text, \'phone\': phoneCtrl.text};',
      '                   if (role == \'delivery_partner\') updates[\'service_pincode\'] = pincodeCtrl.text;',
      '                   await FirebaseFirestore.instance.collection(\'users\').doc(userId).update(updates);',
      '                   if (mounted) Navigator.pop(context);',
      '                 } catch (e) { print(e); }',
      '             }, child: const Text(\'Save\'))',
      '          ],',
      '        ),',
      '      );',
      '  }',
      '',
      '  Future<void> _deleteUser(String userId, String email) async {',
      '     final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(',
      '         title: const Text(\'Delete?\'), actions: [',
      '             TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text(\'No\')),',
      '             ElevatedButton(onPressed: ()=>Navigator.pop(c, true), child: const Text(\'Yes\')),',
      '         ]));',
      '     if (confirm == true) {',
      '        await FirebaseFirestore.instance.collection(\'users\').doc(userId).delete();',
      '     }',
      '  }',
    ];
    lines.insertAll(lastBrace, newMethods);
  }

  await file.writeAsString(lines.join('\n'));
  print('Updated CoreStaffDashboardScreen');
}
