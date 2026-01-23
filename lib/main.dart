import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerce_app/screens/main_navigation_screen.dart';
import 'package:ecommerce_app/screens/cart_screen.dart';
import 'package:ecommerce_app/screens/checkout_screen.dart';
import 'package:ecommerce_app/screens/product_detail_screen.dart';
import 'package:ecommerce_app/screens/category_products_screen.dart';
import 'package:ecommerce_app/screens/auth_screen.dart';
import 'package:ecommerce_app/screens/account_screen.dart';
import 'package:ecommerce_app/screens/edit_profile_screen.dart';
import 'package:ecommerce_app/screens/admin_panel_screen.dart';
import 'package:ecommerce_app/screens/join_partner_screen.dart';
import 'package:ecommerce_app/screens/check_partner_status_screen.dart';
import 'package:ecommerce_app/screens/seller_dashboard_screen.dart';
import 'package:ecommerce_app/screens/book_service_screen.dart';
import 'package:ecommerce_app/screens/service_provider_dashboard_screen.dart';
import 'package:ecommerce_app/screens/delivery_partner_dashboard_screen.dart';
import 'package:ecommerce_app/screens/core_staff_dashboard_screen.dart';
import 'package:ecommerce_app/screens/store_manager_dashboard_screen.dart';
import 'package:ecommerce_app/screens/category_service_providers_screen.dart';
import 'package:ecommerce_app/models/service_category_model.dart';

import 'package:ecommerce_app/screens/my_orders_screen.dart';
import 'package:ecommerce_app/screens/manage_addresses_screen.dart';
import 'package:ecommerce_app/models/product_model.dart';
import 'package:ecommerce_app/providers/cart_provider.dart';
import 'package:ecommerce_app/providers/auth_provider.dart';
import 'package:ecommerce_app/providers/order_provider.dart';
import 'package:ecommerce_app/providers/address_provider.dart';
import 'package:ecommerce_app/providers/product_provider.dart';
import 'package:ecommerce_app/providers/theme_provider.dart';
import 'package:ecommerce_app/providers/category_provider.dart';
import 'package:ecommerce_app/providers/service_category_provider.dart';
import 'package:ecommerce_app/providers/featured_section_provider.dart';
import 'package:ecommerce_app/providers/gift_provider.dart';
import 'package:ecommerce_app/services/recommendation_service.dart';
import 'package:ecommerce_app/providers/settings_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  runApp(const MyApp());
}

// Custom scroll behavior to remove hover effects
class NoHoverScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Don't show scrollbars
    return child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<AuthProvider, OrderProvider>(
          create: (context) => OrderProvider(context.read<AuthProvider>()),
          update: (context, auth, previous) => previous ?? OrderProvider(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, AddressProvider>(
          create: (context) => AddressProvider(context.read<AuthProvider>()),
          update: (context, auth, previous) =>
              previous ?? AddressProvider(auth),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = ProductProvider();
            provider.startListening();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = CategoryProvider();
            provider.startListening();
            provider.seedDefaultCategories(); // Seed categories if missing
            return provider;
          },
        ),
        // GiftProvider for managing gift items
        ChangeNotifierProvider(
          create: (_) {
            final provider = GiftProvider();
            provider.startListening();
            return provider;
          },
        ),
        // ServiceCategoryProvider with realtime listener
        ChangeNotifierProvider(
          create: (_) {
            final provider = ServiceCategoryProvider();
            provider.startListening();
            return provider;
          },
        ),
        // FeaturedSectionProvider enabled
        ChangeNotifierProvider(
          create: (_) {
            final provider = FeaturedSectionProvider();
            provider.fetchSections();
            return provider;
          },
        ),
        // RecommendationService
        ChangeNotifierProvider(
          create: (_) => RecommendationService(),
        ),
        // SettingsProvider
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Dimandy',
            themeMode: themeProvider.themeMode,
            scrollBehavior: NoHoverScrollBehavior(),
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF9C27B0), // Modern purple
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              iconButtonTheme: const IconButtonThemeData(
                style: ButtonStyle(
                  overlayColor: WidgetStatePropertyAll(Colors.transparent),
                ),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFB71C1C), // Deep red
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              iconButtonTheme: const IconButtonThemeData(
                style: ButtonStyle(
                  overlayColor: WidgetStatePropertyAll(Colors.transparent),
                ),
              ),
            ),
            home: const MainNavigationScreen(),
            routes: {
              CartScreen.routeName: (_) => const CartScreen(),
              CheckoutScreen.routeName: (_) => const CheckoutScreen(),
              CategoryProductsScreen.routeName: (_) =>
                  const CategoryProductsScreen(),
              AuthScreen.routeName: (ctx) => const AuthScreen(),
              AccountScreen.routeName: (ctx) => const AccountScreen(),
              EditProfileScreen.routeName: (ctx) => const EditProfileScreen(),
              AdminPanelScreen.routeName: (ctx) => const _AdminPanelGuard(),
              JoinPartnerScreen.routeName: (ctx) => const JoinPartnerScreen(),
              CheckPartnerStatusScreen.routeName: (ctx) =>
                  const CheckPartnerStatusScreen(),
              SellerDashboardScreen.routeName: (ctx) =>
                  const SellerDashboardScreen(),
              ServiceProviderDashboardScreen.routeName: (ctx) =>
                  const ServiceProviderDashboardScreen(),
              CoreStaffDashboardScreen.routeName: (ctx) =>
                  const CoreStaffDashboardScreen(),
              StoreManagerDashboardScreen.routeName: (ctx) =>
                  const StoreManagerDashboardScreen(),
              // BookServiceScreen removed from routes - handled in onGenerateRoute
            },
            // For routes needing arguments
            onGenerateRoute: (settings) {
              if (settings.name == ProductDetailScreen.routeName) {
                final product = settings.arguments as Product;
                return MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: product),
                );
              }
              if (settings.name == BookServiceScreen.routeName) {
                final args = settings.arguments as Map<String, dynamic>?;

                if (args != null) {
                  return MaterialPageRoute(
                    builder: (_) => BookServiceScreen(
                      serviceName: args['serviceName'] as String? ?? '',
                      providerName: args['providerName'] as String? ?? '',
                      providerId: args['providerId'] as String? ?? '',
                      providerImage: args['providerImage'] as String?,
                      ratePerKm: (args['ratePerKm'] as num?)?.toDouble() ?? 0.0,
                      minBookingAmount: (args['minBookingAmount'] as num?)?.toDouble() ?? 0.0,
                      preBookingAmount: (args['preBookingAmount'] as num?)?.toDouble() ?? 0.0,
                    ),
                  );
                }
              }
              if (settings.name == '/my-orders') {
                return MaterialPageRoute(
                  builder: (_) => const MyOrdersScreen(),
                );
              }
              if (settings.name == '/delivery-dashboard') {
                return MaterialPageRoute(
                  builder: (_) => const DeliveryPartnerDashboardScreen(),
                );
              }

              if (settings.name == ManageAddressesScreen.routeName) {
                return MaterialPageRoute(
                  builder: (_) => const ManageAddressesScreen(),
                );
              }
              if (settings.name == ManageAddressesScreen.routeName) {
                return MaterialPageRoute(
                  builder: (_) => const ManageAddressesScreen(),
                );
              }
              if (settings.name == CategoryServiceProvidersScreen.routeName) {
                final category = settings.arguments as ServiceCategory;
                return MaterialPageRoute(
                  builder: (_) => CategoryServiceProvidersScreen(category: category),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

// Route-level guard to ensure only admins can open Admin Panel
class _AdminPanelGuard extends StatelessWidget {
  const _AdminPanelGuard();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: true);

    // Not logged in: show Auth screen
    if (!auth.isLoggedIn) {
      // Optionally, you could pushNamed(AuthScreen.routeName) instead
      return const AuthScreen();
    }

    // Logged in but not admin: block access
    if (!auth.isAdmin) {
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
