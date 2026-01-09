import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/manage_addresses_screen.dart';

Future<void> showMoreBottomSheet(BuildContext context) {
  final theme = Theme.of(context);
  // Keep a reference to the parent page context so we can navigate after closing the sheet
  final parentContext = context;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return DraggableScrollableSheet(
        // Initial height increased to show more content
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        // Smooth snapping between useful sizes
        snap: true,
        snapSizes: const [0.5, 0.65, 0.95],
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: _MoreSheetContent(
              scrollController: scrollController,
              rootContext: parentContext,
            ),
          );
        },
      );
    },
  );
}

class _MoreSheetContent extends StatelessWidget {
  final ScrollController scrollController;
  // Context of the page that opened the sheet
  final BuildContext rootContext;
  const _MoreSheetContent({
    required this.scrollController,
    required this.rootContext,
  });

  Future<String?> _getVersionSafe() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoggedIn = authProvider.currentUser != null;

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 42,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        // No close icon; tap outside to dismiss
        // Content list
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              // Menu buttons (Notifications removed, aligned in two columns)
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth =
                      (constraints.maxWidth - 8) /
                      2; // 2 columns with 8px spacing
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _buildHorizontalButton(
                          context,
                          icon: Icons.settings,
                          label: 'Settings',
                          onTap: () => _openSheet(
                            context,
                            'Settings',
                            _settingsContent(context),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _buildHorizontalButton(
                          context,
                          icon: Icons.security,
                          label: 'Privacy & Security',
                          onTap: () => _openSheet(
                            context,
                            'Privacy & Security',
                            _privacyContent(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _buildHorizontalButton(
                          context,
                          icon: Icons.assignment_return,
                          label: 'Return Policy',
                          onTap: () => _openSheet(
                            context,
                            'Return Policy',
                            _returnPolicyContent(),
                          ),
                        ),
                      ),

                      SizedBox(
                        width: itemWidth,
                        child: _buildHorizontalButton(
                          context,
                          icon: Icons.info_outline,
                          label: 'About Us',
                          onTap: () =>
                              _openSheet(context, 'About Us', _aboutContent()),
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Logout button - full width
              if (isLoggedIn) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text(
                            'Are you sure you want to logout?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await context.read<AuthProvider>().signOut();
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return Material(
      color: backgroundColor ?? Theme.of(context).colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: foregroundColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: foregroundColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, String title, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, ctrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Content sections (kept concise, matching MoreScreen content)
  // replaced with detailed version below

  // Helpers
  Widget _infoSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  // FAQ item helper removed as Help Center is removed

  Widget _settingTile(String title, String subtitle, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap ?? () {
        // Show coming soon message if no onTap provided
        // You can customize this behavior
      },
    );
  }

  // Detailed content (mirrors MoreScreen)

  Widget _aboutContentVersion() {
    return FutureBuilder<String?>(
      future: _getVersionSafe(),
      builder: (context, snapshot) {
        final version = snapshot.hasData && snapshot.data != null
            ? 'Version ${snapshot.data!}'
            : 'Version ...';
        return Center(
          child: Text(version, style: const TextStyle(color: Colors.grey)),
        );
      },
    );
  }

  Widget _aboutContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.shade50,
            Colors.purple.shade50,
            Colors.pink.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Dimandy',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.deepPurple,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: _aboutContentVersion()),
          const SizedBox(height: 24),
          const Text(
            'Dimandy में आपका स्वागत है—एक ऐसा नाम जिसके पीछे केवल व्यापार नहीं, बल्कि एक दिल का गहरा रिश्ता जो बादो पर खरा उतरने से और उनका पूरा करने से बनता है। हमारा सफर उस गाँव की मिट्टी से शुरू होता है जहाँ हमने भोजन की शुद्धता और अपनों की देखभाल का मूल्य सीखा। शहर आकर हमने देखा कि जीवन कितना जटिल है—परिवारों को ताज़गी नहीं मिलती और ज़रूरी काम के लिए भरोसेमंद मदद ढूँढ़ना कितना मुश्किल है। सबसे ज़्यादा हमारा ध्यान उन लोगों पर गया जो अपने परिवार की खातिर घर से दूर रहते हैं या काम में व्यस्त हैं, और हमारे बुज़ुर्गों पर जिन्हें उम्र या स्वास्थ्य के कारण बाज़ार तक जाना कठिन लगता है।',
            style: TextStyle(
              fontSize: 15.5,
              height: 1.7,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 16),
          const Text(
            'Dimandy का जन्म इसी जिम्मेदारी से हुआ है। यह सिर्फ़ एक प्लेटफॉर्म नहीं है; यह एक भरोसेमंद साथी है जो गाँव की शुद्धता को आपकी व्यस्त ज़िंदगी को सुविधा से जोड़ता है। हमारा लक्ष्य केवल डिलीवरी देना नहीं है, बल्कि आपको यह आश्वासन देना है कि जब आप काम में व्यस्त हों या घर पर आराम कर रहे हों या फिर आप अपने परिवार से दूर हो तो आपके परिवार को बेहतरीन पोषण और घर की देखभाल के साथ। और आपके घर तक हर सुविधा पहुंचना है हमारा पहला वादा है ग्रॉसरी में अटूट विश्वास। हम सीधे किसानों से ताज़ी और शुद्ध उपज लाते हैं। आपको Dimandy ऐप पर हर फल, हर सब्ज़ी में गाँव की शुद्धता मिलेगी। और हाँ, हम यह सब आपके अपनों तक पहुँचाने के लिए कोई डिलीवरी शुल्क नहीं लेते हैं।',
            style: TextStyle(
              fontSize: 15.5,
              height: 1.7,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 16),
          const Text(
            'हमारा दूसरा वादा है घर की देखभाल में राहत। हमने समझा कि घर के अचानक बिगड़े हुए काम बुज़ुर्गों और व्यस्त लोगों के लिए बड़ी चिंता बन जाते हैं। इसलिए, हमने सत्यापित और अनुभवी पेशेवरों की एक टीम बनाई है जो ऐप बुकिंग पर तुरंत उपलब्ध होते हैं। चाहे वह इलेक्ट्रीशियन, प्लंबर, कारपेंटर की तकनीकी सेवाएँ हों, बाथरूम की सफ़ाई हो, या स्थानीय गाड़ी बुकिंग—हम हर ज़रूरत का समाधान हैं और यह सब सुविधा आपको कम से कम कीमत यानी जितना कम उतनी ही कीमत में उपलब्ध होगी।',
            style: TextStyle(
              fontSize: 15.5,
              height: 1.7,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 16),
          const Text(
            'Dimandy में हम व्यक्तिगत रूप से इस बात की गारंटी देते हैं कि आपको हमेशा सर्वोत्तम ही मिले। आपका विश्वास ही हमारी सबसे बड़ी कमाई है। आप हमारे Dimandy ऐप के माध्यम से आसानी से ऑर्डर या बुकिंग कर सकते हैं, या किसी भी ज़रूरत के लिए हमें सीधे 7479223366 पर कॉल कर सकते हैं। हमें आपकी सेवा करने और आपके अपनों की देखभाल में मदद करने का अवसर दें।',
            style: TextStyle(
              fontSize: 15.5,
              height: 1.7,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.shade200, width: 2),
            ),
            child: const Column(
              children: [
                Text(
                  '❤️ आपका विश्वास, हमारा सबसे गहरा रिश्ता है।',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: Colors.deepPurple,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Dimandy',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _privacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoSection(
          'Data Collection',
          'We collect personal information such as name, email, phone number, and address to process your orders and provide better services.',
        ),
        _infoSection(
          'Data Usage',
          'Your data is used to:\n• Process orders and payments\n• Provide customer support\n• Send order updates and notifications\n• Improve our services',
        ),
        _infoSection(
          'Data Security',
          'We implement industry-standard security measures to protect your personal information. All payment transactions are encrypted and secure.',
        ),
        _infoSection(
          'Third-Party Sharing',
          'We do not sell your personal data to third parties. We may share data with payment processors and delivery partners only to fulfill your orders.',
        ),
        _infoSection(
          'Your Rights',
          'You have the right to:\n• Access your personal data\n• Request data correction\n• Request data deletion\n• Opt-out of marketing communications',
        ),
        _infoSection(
          'Cookies',
          'We use cookies to improve your browsing experience and remember your preferences. You can disable cookies in your browser settings.',
        ),
      ],
    );
  }

  Widget _returnPolicyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoSection(
          'Return Window',
          'You can return most items within 7 days of delivery for a full refund or exchange.',
        ),
        _infoSection(
          'Eligible Items',
          'Items must be:\n• Unused and in original condition\n• In original packaging with tags\n• Accompanied by invoice/receipt\n• Not damaged or altered',
        ),
        _infoSection(
          'Non-Returnable Items',
          '• Perishable goods (food, beverages)\n• Personal care items\n• Intimate apparel\n• Customized or personalized items\n• Gift cards',
        ),
        _infoSection(
          'Return Process',
          '1. Contact customer support within 7 days\n2. Provide order details and reason\n3. Pack item securely in original packaging\n4. Schedule pickup or drop-off\n5. Refund processed within 7-10 business days',
        ),
        _infoSection(
          'Refund Method',
          'Refunds will be credited to the original payment method. Processing time varies by bank/payment provider.',
        ),
        _infoSection(
          'Exchange',
          'If you want to exchange an item, return the original item and place a new order for the desired product.',
        ),
      ],
    );
  }

  Widget _settingsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            return _settingTile(
              'Notifications',
              settings.notificationsEnabled ? 'On' : 'Off',
              settings.notificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off_outlined,
              onTap: () {
                settings.toggleNotifications(!settings.notificationsEnabled);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      settings.notificationsEnabled
                          ? 'Notifications enabled'
                          : 'Notifications disabled',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            );
          },
        ),
        Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            return _settingTile(
              'Language',
              settings.getLanguageName(),
              Icons.language,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Choose Language'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<String>(
                          title: const Text('English'),
                          value: 'en',
                          groupValue: settings.language,
                          onChanged: (value) {
                            settings.setLanguage(value!);
                            Navigator.pop(dialogContext);
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('Hindi (हिंदी)'),
                          value: 'hi',
                          groupValue: settings.language,
                          onChanged: (value) {
                            settings.setLanguage(value!);
                            Navigator.pop(dialogContext);
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('Bengali (বাংলা)'),
                          value: 'bn',
                          groupValue: settings.language,
                          onChanged: (value) {
                            settings.setLanguage(value!);
                            Navigator.pop(dialogContext);
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        _settingTile(
          'Theme',
          'Auto (System default)',
          Icons.palette_outlined,
          onTap: () {
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Choose Theme'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<ThemeMode>(
                      title: const Text('Light'),
                      value: ThemeMode.light,
                      groupValue: Provider.of<ThemeProvider>(context, listen: false).themeMode,
                      onChanged: (value) {
                        Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                        Navigator.pop(dialogContext);
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Dark'),
                      value: ThemeMode.dark,
                      groupValue: Provider.of<ThemeProvider>(context, listen: false).themeMode,
                      onChanged: (value) {
                        Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                        Navigator.pop(dialogContext);
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        ),
        _settingTile(
          'Data & Storage',
          'Manage cache and data',
          Icons.storage,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage settings coming soon')),
            );
          },
        ),
        _settingTile(
          'Payment Methods',
          'Manage saved cards',
          Icons.payment,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment settings coming soon')),
            );
          },
        ),
        _settingTile(
          'Addresses',
          'Manage delivery addresses',
          Icons.location_on_outlined,
          onTap: () {
            Navigator.pop(context); // Close bottom sheet
            Navigator.of(context).pushNamed(ManageAddressesScreen.routeName);
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'App Version',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        FutureBuilder<String?>(
          future: _getVersionSafe(),
          builder: (context, snapshot) {
            final version = snapshot.hasData && snapshot.data != null
                ? snapshot.data!
                : 'v...';
            return Text(version);
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
          },
          icon: const Icon(Icons.cached),
          label: const Text('Clear Cache'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  // Help Center content removed per request

  // Notifications content removed per request
}
