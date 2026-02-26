import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/razorpay_stub.dart'
    if (dart.library.html) '../../services/razorpay_web.dart' as razorpay_web;

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  Razorpay? _razorpay; // null on web
  String? _customerId;
  List<Map<String, dynamic>> _savedUpiIds = [];

  // UPI Apps list with actual functionality
  final List<Map<String, dynamic>> _upiApps = [
    {
      'name': 'Google Pay',
      'package': 'com.google.android.apps.nbu.paisa.user',
      'color': Colors.blue,
      'icon': Icons.g_mobiledata
    },
    {
      'name': 'PhonePe',
      'package': 'com.phonepe.app',
      'color': Colors.purple,
      'icon': Icons.phone_android
    },
    {
      'name': 'Paytm',
      'package': 'net.one97.paytm',
      'color': Colors.blue,
      'icon': Icons.currency_rupee
    },
    {
      'name': 'BHIM',
      'package': 'in.org.npci.upiapp',
      'color': Colors.orange,
      'icon': Icons.account_balance
    },
    {
      'name': 'Amazon Pay',
      'package': 'in.amazon.mShop.android.shopping',
      'color': Colors.blue,
      'icon': Icons.shopping_bag
    },
  ];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
    _loadCustomerId();
    _loadSavedUpiIds();
  }

  Future<void> _loadCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customerId = prefs.getString('customer_id');
    });
  }

  Future<void> _loadSavedUpiIds() async {
    if (_customerId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(_customerId)
          .get();

      if (doc.exists && doc.data()?.containsKey('savedUpiIds') == true) {
        setState(() {
          _savedUpiIds =
              List<Map<String, dynamic>>.from(doc.data()!['savedUpiIds'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading UPI IDs: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _showSuccessDialog(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Processing with ${response.walletName}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showSuccessDialog(PaymentSuccessResponse response) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Payment Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment ID: ${response.paymentId}'),
            SizedBox(height: 8),
            Text('Paid via: UPI',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // ============ INTERACTIVE FUNCTIONS ============

  // Function 1: Quick UPI Payment Button
  void _payWithUPI() {
    if (kIsWeb) {
      // Use Razorpay JavaScript SDK on web
      final key = razorpay_web.getRazorpayKey() ?? 'Test Key';
      razorpay_web.openRazorpayWeb(
        key: key,
        amount: 10000, // ₹100
        currency: 'INR',
        name: 'Servus Services',
        description: 'Payment for service',
        prefillEmail: 'user@example.com',
        prefillContact: '9999999999',
        onSuccess: (paymentId) {
          if (!mounted) return;
          _showWebSuccessDialog(paymentId);
        },
        onError: (message) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment Failed: $message'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    } else {
      // Use razorpay_flutter on mobile
      var options = {
        'key': 'Test Key', // Replace with your test key
        'amount': 10000, // ₹100
        'currency': 'INR',
        'name': 'Servus Services',
        'description': 'Payment for service',
        'prefill': {
          'email': 'user@example.com',
          'contact': '9999999999',
        },
        'theme': {
          'color': '#2196F3',
        },
      };

      try {
        _razorpay!.open(options);
      } catch (e) {
        debugPrint('Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening payment: $e')),
        );
      }
    }
  }

  void _showWebSuccessDialog(String paymentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Payment Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment ID: $paymentId'),
            SizedBox(height: 8),
            Text('Paid via: UPI',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Function 2: QR Code Scanner
  void _scanQRCode() async {
    // First, check if we have camera permission
    // For demo, we'll show how it would work

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scan QR Code',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 20),
            // Simulated QR scanner view
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white54,
                        size: 80,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Point your camera at a UPI QR code',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              'You can scan QR codes from any UPI app',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Simulate successful scan
                _simulateQRPayment();
              },
              child: Text('Start Scanning'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2196F3),
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _simulateQRPayment() {
    // Show UPI ID entry after scan
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('QR Code Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('UPI ID: worker@okhdfcbank'),
            SizedBox(height: 10),
            Text('Amount: ₹500'),
            SizedBox(height: 20),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Enter Amount',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _payWithUPI(); // Proceed to payment
            },
            child: Text('Pay'),
          ),
        ],
      ),
    );
  }

  // Function 3: Tap on UPI App Icons
  void _openUpiApp(Map<String, dynamic> app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Open ${app['name']}'),
        content: Text(
            'This would open the ${app['name']} app for payment.\n\nIn a real app, you would be redirected to the app to complete payment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _payWithUPI(); // Fallback to Razorpay UPI
            },
            child: Text('Continue with UPI'),
          ),
        ],
      ),
    );
  }

  // Function 4: Add UPI ID
  void _addUpiId() {
    showDialog(
      context: context,
      builder: (context) => _buildAddUpiDialog(),
    );
  }

  Widget _buildAddUpiDialog() {
    final TextEditingController upiController = TextEditingController();
    final TextEditingController nicknameController = TextEditingController();
    String selectedApp = 'Google Pay';

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('Add UPI ID'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: upiController,
                decoration: InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'username@okhdfcbank',
                  prefixIcon: Icon(Icons.payment),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: nicknameController,
                decoration: InputDecoration(
                  labelText: 'Nickname (Optional)',
                  hintText: 'My Primary UPI',
                  prefixIcon: Icon(Icons.label),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedApp,
                decoration: InputDecoration(
                  labelText: 'Preferred App',
                  prefixIcon: Icon(Icons.phone_android),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _upiApps.map((app) {
                  return DropdownMenuItem<String>(
                    value: app['name'],
                    child: Text(app['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedApp = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (upiController.text.isNotEmpty) {
                  _saveUpiId(
                    upiController.text,
                    nicknameController.text.isEmpty
                        ? 'My UPI'
                        : nicknameController.text,
                    selectedApp,
                  );
                  Navigator.pop(context);
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveUpiId(String upiId, String nickname, String appName) async {
    if (_customerId == null) return;

    final newUpi = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'upiId': upiId,
      'nickname': nickname,
      'appName': appName,
      'isDefault': _savedUpiIds.isEmpty,
      'addedDate': DateTime.now().toIso8601String(),
    };

    setState(() {
      _savedUpiIds.add(newUpi);
    });

    await FirebaseFirestore.instance
        .collection('customers')
        .doc(_customerId)
        .set({
      'savedUpiIds': _savedUpiIds,
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('UPI ID saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Function 5: Pay with Saved UPI
  void _payWithSavedUpi(Map<String, dynamic> upi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pay with ${upi['nickname']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('UPI ID: ${upi['upiId']}'),
            SizedBox(height: 10),
            Text('via ${upi['appName']}'),
            SizedBox(height: 20),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Enter Amount',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _payWithUPI(); // Proceed to payment
            },
            child: Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  // Function 6: Show UPI Help
  void _showUpiHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About UPI Payments'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpPoint('✓ Instant payments 24/7'),
            _buildHelpPoint('✓ No card details needed'),
            _buildHelpPoint('✓ Direct from bank account'),
            _buildHelpPoint('✓ Works with all UPI apps'),
            _buildHelpPoint('✓ Safe and secure'),
            SizedBox(height: 10),
            Text(
              'How to get UPI ID?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text('Open any UPI app → Bank Account → Get UPI ID'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpPoint(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(text),
    );
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Payment Methods'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showUpiHelp, // TAPPABLE: Help icon
          ),
          IconButton(
            icon: Icon(Icons.qr_code_scanner),
            onPressed: _scanQRCode, // TAPPABLE: QR Scanner
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Quick UPI Payment Banner - TAPPABLE
            GestureDetector(
              onTap: _payWithUPI, // TAPPABLE: Entire banner
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(51),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Quick UPI Payment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pay using any UPI app instantly',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _payWithUPI, // TAPPABLE: Button
                      icon: const Icon(Icons.payment),
                      label: const Text('Pay with UPI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2196F3),
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Popular UPI Apps - ALL TAPPABLE
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Popular UPI Apps',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _upiApps.map((app) {
                      return GestureDetector(
                        onTap: () =>
                            _openUpiApp(app), // TAPPABLE: Each app icon
                        child: Column(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: app['color'].withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                app['icon'],
                                color: app['color'],
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              app['name'],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Saved UPI IDs Section
            if (_savedUpiIds.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Saved UPI IDs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: _addUpiId, // TAPPABLE: Add new button
                      child: const Text('+ Add New'),
                    ),
                  ],
                ),
              ),
              ..._savedUpiIds.map((upi) => GestureDetector(
                    onTap: () =>
                        _payWithSavedUpi(upi), // TAPPABLE: Each saved UPI
                    child: _buildSavedUpiCard(upi),
                  )),
            ],

            // Add First UPI ID (if none saved) - TAPPABLE
            if (_savedUpiIds.isEmpty)
              GestureDetector(
                onTap: _addUpiId, // TAPPABLE: Entire card
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withAlpha(51),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withAlpha(26),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_card,
                          size: 40,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No UPI IDs saved',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add your UPI ID for faster payments',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addUpiId, // TAPPABLE: Button
                        icon: const Icon(Icons.add),
                        label: const Text('Add UPI ID'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // UPI Benefits Card - TAPPABLE for help
            GestureDetector(
              onTap: _showUpiHelp, // TAPPABLE: Learn more
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Why use UPI?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.arrow_forward, color: Colors.blue.shade700),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedUpiCard(Map<String, dynamic> upi) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.payment,
            color: Color(0xFF2196F3),
          ),
        ),
        title: Text(upi['nickname']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              upi['upiId'],
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            Text(
              'via ${upi['appName']}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (upi['isDefault'] == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Default',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            PopupMenuButton(
              icon: Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(Icons.payment, color: Colors.blue),
                    title: Text('Pay Now'),
                  ),
                  onTap: () => _payWithSavedUpi(upi),
                ),
                if (upi['isDefault'] != true)
                  PopupMenuItem(
                    child: ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('Set as Default'),
                    ),
                    onTap: () => _setDefaultUpi(upi['id']),
                  ),
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Remove'),
                  ),
                  onTap: () => _removeUpi(upi['id']),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _payWithSavedUpi(upi), // TAPPABLE: Entire card
      ),
    );
  }

  void _setDefaultUpi(String upiId) {
    setState(() {
      for (var upi in _savedUpiIds) {
        upi['isDefault'] = upi['id'] == upiId;
      }
    });
    _saveUpiIdsToFirestore();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Default UPI ID updated'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeUpi(String upiId) {
    setState(() {
      _savedUpiIds.removeWhere((upi) => upi['id'] == upiId);
    });
    _saveUpiIdsToFirestore();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('UPI ID removed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _saveUpiIdsToFirestore() async {
    if (_customerId == null) return;

    await FirebaseFirestore.instance
        .collection('customers')
        .doc(_customerId)
        .set({
      'savedUpiIds': _savedUpiIds,
    }, SetOptions(merge: true));
  }
}
