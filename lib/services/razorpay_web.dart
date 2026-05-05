// lib/services/razorpay_web.dart
// Web implementation - uses dart:html to access Razorpay JS SDK
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

void openRazorpayWeb({
  required String key,
  required int amount,
  required String currency,
  required String name,
  required String description,
  required String prefillEmail,
  required String prefillContact,
  required Function(String paymentId) onSuccess,
  required Function(String message) onError,
}) {
  try {
    // Check if Razorpay SDK is loaded
    final razorpayConstructor = js.JsObject.fromBrowserObject(
      html.window
    )['Razorpay'];

    if (razorpayConstructor == null) {
      onError('Razorpay SDK not loaded. Please refresh the page.');
      return;
    }

    bool paymentCompleted = false;

    final options = js.JsObject.jsify({
      'key': key,
      'amount': amount,
      'currency': currency,
      'name': name,
      'description': description,
      'prefill': {
        'email': prefillEmail,
        'contact': prefillContact,
      },
      'theme': {
        'color': '#2196F3',
      },
      'handler': (dynamic response) {
        paymentCompleted = true;
        final resp = js.JsObject.fromBrowserObject(response);
        final paymentId = resp['razorpay_payment_id']?.toString() ?? '';
        onSuccess(paymentId);
      },
    });

    final razorpay = js.JsObject(razorpayConstructor as js.JsFunction, [options]);
    razorpay.callMethod('open');

    // Poll DOM for modal close — works in both debug and release builds
    // ondismiss JS callbacks are unreliable in Flutter web release mode
    Timer(const Duration(seconds: 1), () {
      Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (paymentCompleted) {
          timer.cancel();
          return;
        }
        final container = html.document.querySelector('.razorpay-container');
        if (container == null) {
          timer.cancel();
          onError('Payment cancelled by user');
        }
      });
    });
  } catch (e) {
    onError('Failed to open Razorpay: $e');
  }
}

String? getRazorpayKey() {
  try {
    final env = js.context['ENV'];
    if (env != null) {
      final key = env['RAZORPAY_KEY_ID'];
      if (key != null) return key.toString();
    }
  } catch (_) {}
  return null;
}
