import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order_model.dart';
import '../models/user_model.dart';
import '../providers/database_service.dart';

class ActiveDeliveryScreen extends StatelessWidget {
  final String orderId;

  const ActiveDeliveryScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Active Delivery')),
      body: StreamBuilder<OrderModel?>(
        stream: db.getOrder(orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final order = snapshot.data;
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${_shortOrderId(order.orderId)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, size: 60, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'Navigation (Coming Soon)',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Current: ${order.getStatusDisplay()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _buildCustomerCard(context, db, order.customerId),

                const SizedBox(height: 24),

                _buildLocationCard(
                  context,
                  'Pickup Location',
                  order.pickupAddress,
                  order.pickupContact,
                  order.pickupPhone,
                  order.pickupLat,
                  order.pickupLng,
                  Icons.location_on_outlined,
                ),

                const SizedBox(height: 16),

                _buildLocationCard(
                  context,
                  'Delivery Location',
                  order.deliveryAddress,
                  order.deliveryContact,
                  order.deliveryPhone,
                  order.deliveryLat,
                  order.deliveryLng,
                  Icons.location_on,
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Parcel Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Size:'),
                          Text(
                            order.parcelSize.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (order.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Description: '),
                            Expanded(
                              child: Text(
                                order.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('COD Amount:'),
                          Text(
                            'Rs. ${order.amount.toInt()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF2ECC71),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                _buildStatusAction(context, db, order),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusAction(
    BuildContext context,
    DatabaseService db,
    OrderModel order,
  ) {
    if (order.status == 'assigned') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _runStatusUpdate(
            context,
            () => db.updateOrderStatus(order.orderId, 'picked_up'),
            'Marked as Picked Up!',
          ),
          child: const Text('MARK AS PICKED UP'),
        ),
      );
    }

    if (order.status == 'picked_up' || order.status == 'in_transit') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _runStatusUpdate(
            context,
            () => db.markAsDelivered(order.orderId),
            'Delivery Completed!',
            popAfterSuccess: true,
          ),
          child: const Text('MARK AS DELIVERED'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCustomerCard(
    BuildContext context,
    DatabaseService db,
    String customerId,
  ) {
    return StreamBuilder<UserModel?>(
      stream: db.getUser(customerId),
      builder: (context, snapshot) {
        final customer = snapshot.data;
        final phone = customer?.phone ?? '';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('Name: ${customer?.name ?? customerId}'),
              if (phone.isNotEmpty) Text('Phone: $phone'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: phone.isEmpty
                      ? null
                      : () => _callPhone(context, phone),
                  icon: const Icon(Icons.phone),
                  label: const Text('Call Customer'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationCard(
    BuildContext context,
    String title,
    String address,
    String contact,
    String phone,
    double latitude,
    double longitude,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2ECC71)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(address),
          const SizedBox(height: 8),
          Text('Contact: $contact'),
          Text('Phone: $phone'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callPhone(context, phone),
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openNavigation(context, latitude, longitude),
                  icon: const Icon(Icons.navigation, size: 18),
                  label: const Text('Navigate'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _runStatusUpdate(
    BuildContext context,
    Future<void> Function() updateStatus,
    String successMessage, {
    bool popAfterSuccess = false,
  }) async {
    try {
      await updateStatus();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
      );

      if (popAfterSuccess) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _callPhone(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await _launchExternalUri(context, uri, 'Could not open phone app');
  }

  Future<void> _openNavigation(
    BuildContext context,
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    });

    await _launchExternalUri(context, uri, 'Could not open navigation');
  }

  Future<void> _launchExternalUri(
    BuildContext context,
    Uri uri,
    String errorMessage,
  ) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$errorMessage: $e')));
    }
  }

  String _shortOrderId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }
}
