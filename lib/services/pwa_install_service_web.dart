// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

bool triggerPWAInstallImpl() {
  try {
    final ready = js.context['pwaInstallReady'];
    if (ready == true) {
      js.context.callMethod('triggerPWAInstall');
      return true;
    }
  } catch (e) {
    debugPrint('PWA install error: $e');
  }
  return false;
}

bool isPWAInstallReadyImpl() {
  try {
    return js.context['pwaInstallReady'] == true;
  } catch (_) {
    return false;
  }
}

void onPWAInstallReadyImpl(VoidCallback callback) {
  try {
    js.context['_onPwaReady'] = js.allowInterop((_) => callback());
  } catch (_) {}
}
