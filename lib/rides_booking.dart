import 'package:flutter/material.dart';
import 'services/firestore_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RidesBookingPage extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> driverDetails;
  final String pickupAddress;
  final String destinationAddress;
  final double fare;
  final String rideType;

  const RidesBookingPage({
    super.key,
    required this.rideId,
    required this.driverDetails,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.fare,
    required this.rideType,
  });

  @override
  State<RidesBookingPage> createState() => _RidesBookingPageState();
}

class _RidesBookingPageState extends State<RidesBookingPage> {
  String _selectedPaymentMethod = 'Cash';
  bool _isLoading = false;
  Map<String, dynamic>? _rideData;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _loadRideData();
    
    // Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear(); // Clear Razorpay listeners
    super.dispose();
  }

  // Handle payment success
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('Payment successful: ${response.paymentId}');
    
    // After successful payment, confirm the booking
    _confirmBookingAfterPayment();
  }

  // Handle payment error
  void _handlePaymentError(PaymentFailureResponse response) {
    print('Payment error: ${response.message}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response.message}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle external wallet
  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External wallet: ${response.walletName}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected wallet: ${response.walletName}'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _loadRideData() async {
    try {
      final rideData = await FirestoreService.getRideById(widget.rideId);
      if (mounted) {
        setState(() {
          _rideData = rideData;
        });
      }
    } catch (e) {
      print('Error loading ride data: $e');
    }
  }

  // Open Razorpay checkout
  void _openCheckout() {
    var options = {
      'key': 'rzp_test_RVQP1hirXQFCVn', // Provided test key
      'amount': (widget.fare * 100).toInt(), // Amount in paise
      'name': 'RideMate',
      'description': 'Ride Payment',
      'prefill': {
        'contact': '',
        'email': '',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Error opening Razorpay: $e');
      // Handle the MissingPluginException by showing an error message and falling back to cash payment
      if (e.toString().contains('MissingPluginException')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment gateway not available. Please use Cash payment method.'),
              backgroundColor: Colors.orange,
            ),
          );
          // Automatically select cash payment method
          setState(() {
            _selectedPaymentMethod = 'Cash';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error opening payment gateway'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _confirmBookingAfterPayment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Update ride status to confirmed
      await FirestoreService.updateRideStatus(widget.rideId, 'confirmed');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking confirmed successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to home or to a tracking page
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmBooking() async {
    setState(() {
      _isLoading = true;
    });

    // If Cash payment method is selected, confirm booking directly
    if (_selectedPaymentMethod == 'Cash') {
      try {
        // Update ride status to confirmed
        await FirestoreService.updateRideStatus(widget.rideId, 'confirmed');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking confirmed successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to home or to a tracking page
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error confirming booking: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // For other payment methods, open Razorpay
      setState(() {
        _isLoading = false; // Reset loading state for Razorpay
      });
      _openCheckout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 800 : double.infinity,
                  ),
                  padding: EdgeInsets.all(isDesktop ? 32 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Driver Details Card
                      _buildDriverDetailsCard(),
                      const SizedBox(height: 16),

                      // Trip Details Card
                      _buildTripDetailsCard(),
                      const SizedBox(height: 16),

                      // Payment Method Card
                      _buildPaymentMethodCard(),
                      const SizedBox(height: 24),

                      // Confirm Booking Button
                      _buildConfirmButton(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildDriverDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Driver',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.deepPurple,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driverDetails['name'] ?? 'Unknown Driver',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            widget.driverDetails['rating']?.toString() ?? '0.0',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.directions_car,
              'Car Model',
              widget.driverDetails['carModel'] ?? 'N/A',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.confirmation_number,
              'Car Number',
              widget.driverDetails['carNumber'] ?? 'N/A',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.phone,
              'Phone',
              widget.driverDetails['phoneNumber'] ?? 'N/A',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripDetailsCard() {
    final distanceKm = _rideData?['routeSummary']?['distanceKm'];
    final durationMin = _rideData?['routeSummary']?['durationMin'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trip Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 16),
            _buildLocationRow(
              Icons.location_on,
              'Pickup',
              widget.pickupAddress,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildLocationRow(
              Icons.location_on,
              'Destination',
              widget.destinationAddress,
              Colors.red,
            ),
            if (distanceKm != null && durationMin != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.straighten,
                    'Distance',
                    '${distanceKm.toStringAsFixed(1)} km',
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  _buildStatItem(
                    Icons.access_time,
                    'Duration',
                    '${durationMin.toStringAsFixed(0)} min',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentOption('Cash', Icons.money),
            const SizedBox(height: 8),
            _buildPaymentOption('UPI', Icons.payment),
            const SizedBox(height: 8),
            _buildPaymentOption('Card', Icons.credit_card),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String method, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple.withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.deepPurple : Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Text(
              method,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.deepPurple : Colors.grey.shade700,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _confirmBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Confirm Booking',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(
    IconData icon,
    String label,
    String address,
    Color iconColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.deepPurple),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _buildFareRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }
}
