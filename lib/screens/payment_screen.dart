import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'feedback_screen.dart';
import '../home.dart';

class PaymentScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const PaymentScreen({
    super.key,
    required this.rideId,
    required this.rideData,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  String? _selectedMethod;
  StreamSubscription? _rideSubscription;

  @override
  void initState() {
    super.initState();
    // Listen for ride status changes (especially for Cash payment confirmation)
    _rideSubscription = FirestoreService.getRideStream(widget.rideId).listen((ride) {
      if (ride != null && ride['paymentStatus'] == 'paid') {
        _navigateToFeedback();
      }
    });
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    super.dispose();
  }

  void _navigateToFeedback() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(
          rideId: widget.rideId,
          driverId: widget.rideData['driverId'],
        ),
      ),
    );
  }

  Future<void> _processOnlinePayment() async {
    setState(() {
      _isProcessing = true;
      _selectedMethod = 'online';
    });

    // Simulate payment gateway delay
    await Future.delayed(const Duration(seconds: 3));

    try {
      await FirestoreService.updateRidePaymentStatus(
        widget.rideId,
        method: 'online_upi',
        status: 'completed',
      );
      // navigation is handled by the stream listener
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processCashPayment() async {
    setState(() {
      _isProcessing = true;
      _selectedMethod = 'cash';
    });

    try {
      await FirestoreService.updateRidePaymentStatus(
        widget.rideId,
        method: 'cash',
        status: 'cash_pending',
      );
      // We stay on this screen and wait for driver to confirm "paid"
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fare = widget.rideData['fare']?.toString() ?? '0';
    final driverName = widget.rideData['driver']?['name'] ?? 'your driver';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon or Card
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              const Text(
                'Ride Completed!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please complete the payment for your ride with $driverName',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 48),

              // Fare Display
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL FARE',
                      style: TextStyle(color: Colors.amber, letterSpacing: 2, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹$fare',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              if (_isProcessing && _selectedMethod == 'online') ...[
                const CircularProgressIndicator(color: Colors.amber),
                const SizedBox(height: 16),
                const Text('Connecting to Payment Gateway...', style: TextStyle(color: Colors.white70)),
              ] else if (_isProcessing && _selectedMethod == 'cash') ...[
                const CircularProgressIndicator(color: Colors.amber),
                const SizedBox(height: 16),
                const Text('Waiting for driver confirmation...', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text(
                  'Please pay ₹$fare to the driver in cash.',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ] else ...[
                // Payment Methods
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose payment method',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPaymentMethodTile(
                  title: 'Online Payment (UPI)',
                  subtitle: 'Google Pay, PhonePe, etc.',
                  icon: Icons.account_balance_wallet,
                  color: Colors.deepPurpleAccent,
                  onTap: _processOnlinePayment,
                ),
                const SizedBox(height: 12),
                _buildPaymentMethodTile(
                  title: 'Cash Payment',
                  subtitle: 'Pay directly to the driver',
                  icon: Icons.payments,
                  color: Colors.greenAccent,
                  onTap: _processCashPayment,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
