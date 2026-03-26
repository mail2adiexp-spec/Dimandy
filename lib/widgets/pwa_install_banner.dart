import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/pwa_install_service.dart';

/// Shows a "Install App" banner/button only on Web when the PWA install
/// prompt is available. On Android/iOS this widget renders nothing.
class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  bool _showBanner = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    // Check immediately in case event already fired
    if (isPWAInstallReady()) {
      setState(() => _showBanner = true);
    } else {
      // Listen for when the prompt becomes ready
      onPWAInstallReady(() {
        if (mounted) setState(() => _showBanner = true);
      });
    }
  }

  void _install() {
    triggerPWAInstall();
    setState(() {
      _showBanner = false;
      _dismissed = true;
    });
  }

  void _dismiss() {
    setState(() {
      _showBanner = false;
      _dismissed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_showBanner || _dismissed) return const SizedBox.shrink();

    return Material(
      elevation: 4,
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.install_mobile, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Install Dimandy App',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Faster experience, works offline!',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _install,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              child: const Text('Install'),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 18),
              onPressed: _dismiss,
              tooltip: 'Dismiss',
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
