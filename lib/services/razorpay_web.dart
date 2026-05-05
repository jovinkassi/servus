// lib/services/razorpay_web.dart
// Web implementation - uses dart:html to access Razorpay JS SDK
// ignore_for_file: avoid_web_libraries_in_flutter
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
        final resp = js.JsObject.fromBrowserObject(response);
        final paymentId = resp['razorpay_payment_id']?.toString() ?? '';
        onSuccess(paymentId);
      },
      'modal': {
        'ondismiss': () {
          onError('Payment cancelled by user');
        },
      },
    });

    final razorpay = js.JsObject(razorpayConstructor as js.JsFunction, [options]);
    razorpay.callMethod('open');
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
