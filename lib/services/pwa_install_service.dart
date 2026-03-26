import 'package:flutter/foundation.dart';

// Conditional import: dart:html only on web
import 'pwa_install_service_web.dart'
    if (dart.library.io) 'pwa_install_service_stub.dart';

/// Call this to trigger the native PWA install prompt.
/// Returns true if the prompt was shown (web + prompt available),
/// false otherwise (mobile / prompt not ready).
bool triggerPWAInstall() => triggerPWAInstallImpl();

/// Returns true if the PWA install prompt is currently available.
bool isPWAInstallReady() => isPWAInstallReadyImpl();

/// Register a callback that fires when the install prompt becomes available.
void onPWAInstallReady(VoidCallback callback) =>
    onPWAInstallReadyImpl(callback);
