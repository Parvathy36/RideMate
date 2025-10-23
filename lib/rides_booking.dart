import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firestore_service.dart';

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

class _PaymentDetails {
  final String method;
  final String issuer;
  final String reference;
  final String payerName;

  const _PaymentDetails({
    required this.method,
    required this.issuer,
    required this.reference,
    required this.payerName,
  });
}

class _RidesBookingPageState extends State<RidesBookingPage> {
  String _selectedPaymentMethod = 'Cash';
  bool _isLoading = false;
  Map<String, dynamic>? _rideData;

  @override
  void initState() {
    super.initState();
    _loadRideData();
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

  Future<_PaymentDetails?> _showPaymentDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final referenceController = TextEditingController();
    String selectedIssuer = _selectedPaymentMethod == 'UPI'
        ? 'Google Pay'
        : 'Visa';
    bool isProcessing = false;

    try {
      final result = await showModalBottomSheet<_PaymentDetails?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SafeArea(
                  top: false,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Complete Your Payment',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Securely pay using $_selectedPaymentMethod',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Amount to Pay',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₹${widget.fare.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  value: selectedIssuer,
                                  decoration: InputDecoration(
                                    labelText: _selectedPaymentMethod == 'UPI'
                                        ? 'Preferred UPI App'
                                        : 'Card Network',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items:
                                      (_selectedPaymentMethod == 'UPI'
                                              ? [
                                                  'Google Pay',
                                                  'PhonePe',
                                                  'Paytm',
                                                ]
                                              : ['Visa', 'Mastercard', 'RuPay'])
                                          .map(
                                            (option) => DropdownMenuItem(
                                              value: option,
                                              child: Text(option),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setSheetState(() {
                                        selectedIssuer = value;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: nameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: 'Payer Name',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter payer name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: referenceController,
                                  decoration: InputDecoration(
                                    labelText: _selectedPaymentMethod == 'UPI'
                                        ? 'UPI Transaction ID'
                                        : 'Last 4 digits of card',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  keyboardType: _selectedPaymentMethod == 'UPI'
                                      ? TextInputType.text
                                      : TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter payment reference';
                                    }
                                    if (_selectedPaymentMethod == 'Card' &&
                                        value.trim().length != 4) {
                                      return 'Enter last 4 digits';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isProcessing
                                      ? null
                                      : () {
                                          Navigator.of(context).pop(null);
                                        },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isProcessing
                                      ? null
                                      : () async {
                                          if (formKey.currentState
                                                  ?.validate() !=
                                              true) {
                                            return;
                                          }
                                          setSheetState(() {
                                            isProcessing = true;
                                          });
                                          await Future.delayed(
                                            const Duration(seconds: 2),
                                          );
                                          Navigator.of(context).pop(
                                            _PaymentDetails(
                                              method: _selectedPaymentMethod,
                                              issuer: selectedIssuer,
                                              reference: referenceController
                                                  .text
                                                  .trim(),
                                              payerName: nameController.text
                                                  .trim(),
                                            ),
                                          );
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: isProcessing
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Pay ₹${widget.fare.toStringAsFixed(2)}',
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
      return result;
    } finally {
      nameController.dispose();
      referenceController.dispose();
    }
  }

  Future<void> _finalizeBooking() async {
    try {
      await FirestoreService.updateRideStatus(widget.rideId, 'confirmed');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking confirmed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    if (_selectedPaymentMethod == 'Cash') {
      // Record cash payment details in Firestore
      try {
        final user = FirebaseAuth.instance.currentUser;
        Map<String, dynamic>? userData;
        if (user != null) {
          userData = await FirestoreService.getUserData(user.uid);
        }

        await FirestoreService.recordPayment(
          rideId: widget.rideId,
          amount: widget.fare,
          method: 'Cash',
          reference: 'CASH_PAYMENT',
          issuer: 'N/A',
          payerName: userData?['name'] ?? user?.displayName ?? 'User',
          rideType: widget.rideType,
          driver: widget.driverDetails,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error recording cash payment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _isLoading = true;
      });
      await _finalizeBooking();
      return;
    }

    final paymentCompleted = await _showPaymentDialog();
    if (paymentCompleted == null || !mounted) {
      return;
    }

    // Record payment details in Firestore
    try {
      await FirestoreService.recordPayment(
        rideId: widget.rideId,
        amount: widget.fare,
        method: paymentCompleted.method,
        reference: paymentCompleted.reference,
        issuer: paymentCompleted.issuer,
        payerName: paymentCompleted.payerName,
        rideType: widget.rideType,
        driver: widget.driverDetails,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment received via ${paymentCompleted.method}'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      _isLoading = true;
    });

    await _finalizeBooking();
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
