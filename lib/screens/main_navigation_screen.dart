import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'static_pages.dart';
import 'services_screen.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../providers/service_category_provider.dart';
import '../providers/gift_provider.dart';
import '../providers/featured_section_provider.dart';
import '../providers/product_provider.dart';
import '../widgets/more_bottom_sheet.dart';
import '../widgets/pwa_install_banner.dart';

class MainNavigationScreen extends StatefulWidget {
  static const routeName = '/home-nav';
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Always start from Home screen
    _currentIndex = widget.initialIndex;
    
    // Defer heavy initialization to after the first frame to keep splash smooth
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAppData();
    });
  }

  void _initAppData() {
    if (!mounted) return;
    
    // Start realtime listeners in the background
    context.read<CategoryProvider>().startListening();
    context.read<ServiceCategoryProvider>().startListening();
    context.read<GiftProvider>().startListening();
    
    // Fetch initial static data
    context.read<FeaturedSectionProvider>().fetchSections();
    
    // Initial products fetch (for main list)
    context.read<ProductProvider>().fetchProducts(refresh: true);
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    ServicesScreen(),
    ContactScreen(),
    SizedBox.shrink(), // Placeholder for More (no screen needed)
  ];

  void _onTabTapped(int index) async {
    if (index == 3) {
      // Don't change index, just show sheet
      await showMoreBottomSheet(context);
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const PwaInstallBanner(),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'HOME',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.design_services_outlined),
            activeIcon: Icon(Icons.design_services),
            label: 'SERVICES',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contact_page_outlined),
            activeIcon: Icon(Icons.contact_page),
            label: 'CONTACT',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.menu),
            label: 'MORE',
          ),
        ],
      ),
    );
  }
}
