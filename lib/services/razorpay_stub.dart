// lib/services/razorpay_stub.dart
// Stub for non-web platforms (mobile uses razorpay_flutter directly)

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
  // No-op on mobile — razorpay_flutter is used instead
}

String? getRazorpayKey() {
  return null;
}
