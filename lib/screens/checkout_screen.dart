import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../utils/currency.dart';
import '../models/address_model.dart';
import '../providers/address_provider.dart';
import '../services/notification_service.dart';

class CheckoutScreen extends StatefulWidget {
  static const routeName = '/checkout';

  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedState;
  String _selectedPaymentMethod = 'COD'; // COD or Online
  bool _isPlacingOrder = false;
  bool _saveAddress = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    final auth = context.read<AuthProvider>();
    final addrProvider = context.read<AddressProvider>();

    if (auth.currentUser != null) {
      _nameController.text = auth.currentUser!.name;
      if (auth.currentUser!.phoneNumber != null) {
        _phoneController.text = auth.currentUser!.phoneNumber!;
      }
    }

    await addrProvider.fetch();
    if (addrProvider.defaultAddress != null) {
      _fillFromAddress(addrProvider.defaultAddress!);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (_, cart, __) => Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        
                        // Calculate pre-booking amount from cart items
                        Builder(
                          builder: (context) {
                            double totalPreBooking = 0.0;
                            for (var item in cart.items) {
                              if (item.metadata != null && item.metadata!['preBookingAmount'] != null) {
                                totalPreBooking += (item.metadata!['preBookingAmount'] as num).toDouble();
                              }
                            }
                            
                            final hasPreBooking = totalPreBooking > 0;
                            double remainingAmount = 0.0;
                            try {
                              for (var item in cart.items) {
                                if (item.metadata != null && item.metadata!['remainingAmount'] != null) {
                                  remainingAmount += (item.metadata!['remainingAmount'] as num).toDouble();
                                }
                              }
                            } catch (e) {
                              debugPrint('Error calculating remaining amount: $e');
                            }
                            
                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Items: ${cart.itemCount}'),
                                    Text(
                                      formatINR(cart.totalAmount),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // Show pre-booking breakdown if applicable
                                if (hasPreBooking) ...[
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Pre-booking Amount:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        formatINR(totalPreBooking),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Remaining Amount:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        formatINR(remainingAmount),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Pay remaining amount on service completion',
                                            style: TextStyle(fontSize: 12, color: Colors.blue),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Shipping Address
                const Text(
                  'Delivery Address',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showSavedAddressesSheet(),
                      icon: const Icon(Icons.location_pin),
                      label: const Text('Choose from saved'),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => _openEditAddressDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add New'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter phone number';
                    }
                    if (value.length < 10) {
                      return 'Enter valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.home),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'City',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter city';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _postalCodeController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Postal Code',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter postal code';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedState,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'State',
                  ),
                  items: [
                   'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
                   'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand',
                   'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
                   'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
                   'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
                   'Uttar Pradesh', 'Uttarakhand', 'West Bengal', 'Andaman and Nicobar Islands',
                   'Chandigarh', 'Dadra and Nagar Haveli and Daman and Diu', 'Delhi',
                   'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry'
                  ].map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                  onChanged: (val) => setState(() => _selectedState = val),
                  validator: (v) => v == null ? 'Please select state' : null,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _saveAddress,
                  onChanged: (v) => setState(() => _saveAddress = v ?? true),
                  title: const Text('Save this address for future orders'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 24),

                // Payment Method
                const Text(
                  'Payment Method',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Row(
                          children: [
                            Icon(Icons.money, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Cash on Delivery (COD)'),
                          ],
                        ),
                        subtitle: const Text(
                          'Pay cash at the time of delivery',
                        ),
                        value: 'COD',
                        groupValue: _selectedPaymentMethod,
                        onChanged: (value) {
                          setState(() {
                            _selectedPaymentMethod = value!;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: const Row(
                          children: [
                            Icon(Icons.payment, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Online Payment'),
                          ],
                        ),
                        subtitle: const Text('Secure Online Payment'),
                        value: 'Online',
                        groupValue: _selectedPaymentMethod,
                        onChanged: (value) {
                          setState(() {
                            _selectedPaymentMethod = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

              ],
            ),
          ),
        ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: cart.isEmpty || _isPlacingOrder ? null : _placeOrder,
              icon: _isPlacingOrder
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.shopping_cart_checkout),
              label: Text(
                _isPlacingOrder ? 'Placing Order...' : 'Place Order',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final cart = Provider.of<CartProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    if (!auth.isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please login first')));
      }
      return;
    }

    setState(() {
      _isPlacingOrder = true;
    });

    try {
      final fullAddress =
          '${_addressController.text}, ${_cityController.text}, ${_selectedState!}, ${_postalCodeController.text}';

      // Convert cart items to order items
      final orderItems = cart.items.map((cartItem) {
        return OrderItem(
          productId: cartItem.product.id,
          sellerId: cartItem.product.sellerId,
          productName: cartItem.product.name,
          quantity: cartItem.quantity,
          price: cartItem.product.price,
          imageUrl: cartItem.product.imageUrl,
          metadata: cartItem.metadata,
        );
      }).toList();

      debugPrint('Checkout: Creating order with ${orderItems.length} items');

      // Optionally save address
      if (_saveAddress) {
        final addrProvider = context.read<AddressProvider>();
        await addrProvider.add(
          Address(
            id: '',
            fullName: _nameController.text,
            phone: _phoneController.text,
            addressLine: _addressController.text,
            city: _cityController.text,
            postalCode: _postalCodeController.text,
            state: _selectedState,
            isDefault: addrProvider.defaultAddress == null,
          ),
        );
      }

      final orderId = await orderProvider.createOrder(
        items: orderItems,
        totalAmount: cart.totalAmount,
        deliveryAddress: fullAddress,
        phoneNumber: _phoneController.text,
        state: _selectedState!,
      );

      debugPrint('Checkout: Order ID received: $orderId');

      if (orderId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create order. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Notify Sellers
      try {
        final Set<String> sellerIds = {};
        for (var item in orderItems) {
          if (item.sellerId.isNotEmpty) {
            sellerIds.add(item.sellerId);
          }
        }
        
        final notificationService = NotificationService();
        for (var sellerId in sellerIds) {
          await notificationService.sendNotification(
            toUserId: sellerId,
            title: 'New Order Received',
            body: 'You have a new order (#${orderId.substring(0, 8)}) containing ${orderItems.where((i) => i.sellerId == sellerId).length} items.',
            type: 'order_new',
            relatedId: orderId,
          );
        }
      } catch (e) {
        debugPrint('Error sending notifications: $e');
      }

      // Create bookings for service items
      try {
        for (var item in orderItems) {
          // Check if this is a service item (has metadata with providerId)
          if (item.metadata != null && item.metadata!['providerId'] != null) {
            final bookingId = FirebaseFirestore.instance.collection('bookings').doc().id;
            
            // Calculate platform fee on actual service amount, not customer payment
            // Calculate platform fee
            double platformFeeAmount = 0.0;
            double platformFeePercentage = 0.0;

            if (item.metadata!['serviceType'] == 'transport') {
              // Fixed commission for vehicle bookings
              platformFeeAmount = 50.0;
              platformFeePercentage = 0.0; // Fixed fee, not percentage
            } else {
              // Percentage based for other services
              final serviceAmount = (item.metadata!['serviceAmount'] as num?)?.toDouble() ?? item.price;
              platformFeePercentage = (item.metadata!['platformFeePercentage'] as num?)?.toDouble() ?? 10.0;
              platformFeeAmount = serviceAmount * (platformFeePercentage / 100);
            }

            final serviceAmount = (item.metadata!['serviceAmount'] as num?)?.toDouble() ?? item.price;
            final providerEarnings = item.price - platformFeeAmount; // Customer payment - platform fee
            
            // Calculate remaining amount
            final customerPayment = item.price;
            final remainingAmount = (serviceAmount > customerPayment) 
                ? (serviceAmount - customerPayment) 
                : 0.0;
            
            await FirebaseFirestore.instance.collection('bookings').doc(bookingId).set({
              'id': bookingId,
              'orderId': orderId,
              'providerId': item.metadata!['providerId'],
              'providerName': item.metadata!['providerName'] ?? 'Unknown',
              'customerId': auth.currentUser!.uid,
              'customerName': auth.currentUser!.name,
              'customerPhone': _phoneController.text,
              'serviceName': item.productName,
              'customerPayment': customerPayment, // What customer paid
              'serviceAmount': serviceAmount, // Actual service value
              'remainingAmount': remainingAmount, // Amount to be paid later
              'platformFeePercentage': platformFeePercentage,
              'platformFeeAmount': platformFeeAmount, // Fee calculated on service amount
              'providerEarnings': providerEarnings, // What provider will receive
              'deliveryAddress': fullAddress,
              'status': 'pending', // pending, confirmed, completed, cancelled
              'paymentMethod': _selectedPaymentMethod,
              'createdAt': FieldValue.serverTimestamp(),
              'bookingDate': item.metadata!['bookingDate'],
              'bookingTime': item.metadata!['bookingTime'],
              // Include all service metadata
              'metadata': item.metadata,
            });
            
            debugPrint('✅ Created booking $bookingId for provider ${item.metadata!['providerId']}');
            debugPrint('   💰 Customer Payment: ₹$customerPayment');
            debugPrint('   📊 Service Amount: ₹$serviceAmount');
            debugPrint('   💵 Remaining Amount: ₹$remainingAmount');
            debugPrint('   💳 Platform Fee ($platformFeePercentage%): ₹$platformFeeAmount');
            debugPrint('   👤 Provider Earnings: ₹$providerEarnings');
            
            // Send notification to service provider
            try {
              final notificationService = NotificationService();
              await notificationService.sendNotification(
                toUserId: item.metadata!['providerId'],
                title: 'New Booking Received',
                body: 'You have a new booking for ${item.productName}',
                type: 'booking_new',
                relatedId: bookingId,
              );
            } catch (e) {
              debugPrint('Error sending booking notification: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error creating bookings: $e');
      }

      debugPrint('Checkout: Order created successfully, clearing cart');
      cart.clear();

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 8),
                Text('Order Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your order has been placed successfully!',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Method:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedPaymentMethod == 'COD'
                            ? '💵 Cash on Delivery (COD)'
                            : 'Online Payment',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_selectedPaymentMethod == 'COD') ...[
                        const SizedBox(height: 8),
                        const Text(
                          '✓ Pay cash at the time of delivery',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You can track your order in "My Orders".',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/my-orders');
                },
                child: const Text('View Orders'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Go to Home'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
      }
    }
  }

  void _fillFromAddress(Address a) {
    _nameController.text = a.fullName;
    _phoneController.text = a.phone;
    _addressController.text = a.addressLine;
    _cityController.text = a.city;
    _postalCodeController.text = a.postalCode;
    setState(() {
      _selectedState = a.state;
    });
  }

  Future<void> _showSavedAddressesSheet() async {
    final addrProvider = context.read<AddressProvider>();
    await addrProvider.fetch();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saved Addresses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Consumer<AddressProvider>(
                  builder: (context, ap, _) {
                    if (ap.addresses.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('No saved addresses yet')),
                      );
                    }
                    return Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: ap.addresses.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final a = ap.addresses[i];
                          return ListTile(
                            leading: Icon(
                              a.isDefault ? Icons.star : Icons.location_on,
                              color: a.isDefault ? Colors.amber : null,
                            ),
                            title: Text('${a.fullName}  •  ${a.phone}'),
                            subtitle: Text(
                              '${a.addressLine}, ${a.city} - ${a.postalCode}',
                            ),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _fillFromAddress(a);
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    _openEditAddressDialog(existing: a);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await ap.delete(a.id);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _openEditAddressDialog();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Address'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditAddressDialog({Address? existing}) async {
    final nameCtrl = TextEditingController(
      text: existing?.fullName ?? _nameController.text,
    );
    final phoneCtrl = TextEditingController(
      text: existing?.phone ?? _phoneController.text,
    );
    final lineCtrl = TextEditingController(
      text: existing?.addressLine ?? _addressController.text,
    );
    final cityCtrl = TextEditingController(
      text: existing?.city ?? _cityController.text,
    );
    final pinCtrl = TextEditingController(
      text: existing?.postalCode ?? _postalCodeController.text,
    );
    bool isDefault = existing?.isDefault ?? false;

    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add Address' : 'Edit Address'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  validator: (v) =>
                      (v == null || v.length < 10) ? 'Enter valid phone' : null,
                ),
                TextFormField(
                  controller: lineCtrl,
                  decoration: const InputDecoration(labelText: 'Address'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: pinCtrl,
                  decoration: const InputDecoration(labelText: 'Postal Code'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                StatefulBuilder(
                  builder: (context, setInner) {
                    return CheckboxListTile(
                      value: isDefault,
                      onChanged: (v) => setInner(() => isDefault = v ?? false),
                      title: const Text('Set as default'),
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final provider = context.read<AddressProvider>();
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
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
