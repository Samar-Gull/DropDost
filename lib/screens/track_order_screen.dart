import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order_model.dart';
import '../models/user_model.dart';
import '../providers/database_service.dart';

class TrackOrderScreen extends StatelessWidget {
  final String orderId;

  const TrackOrderScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);

    return StreamBuilder<OrderModel?>(
      stream: db.getOrder(orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final order = snapshot.data;
        if (order == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Order Not Found')),
            body: const Center(child: Text('Order not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text('Order #${_shortOrderId(orderId)}')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          'Map View (Coming Soon)',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Status: ${order.getStatusDisplay()}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2ECC71),
                  ),
                ),
                const SizedBox(height: 24),
                _buildStatusTimeline(order.status),
                const SizedBox(height: 24),
                if (order.riderId != null) ...[
                  _buildRiderInfo(context, db, order),
                  const SizedBox(height: 24),
                ],
                _buildInfoCard(
                  'Pickup Location',
                  order.pickupAddress,
                  order.pickupContact,
                  order.pickupPhone,
                  Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  'Delivery Location',
                  order.deliveryAddress,
                  order.deliveryContact,
                  order.deliveryPhone,
                  Icons.location_on,
                ),
                const SizedBox(height: 16),
                _buildParcelCard(order),
                if (order.status == 'delivered' &&
                    !order.customerAcknowledged) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmReceived(context, db, orderId),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('CONFIRM RECEIVED'),
                    ),
                  ),
                ] else if (order.customerAcknowledged) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Delivery confirmed. Thank you!',
                      style: TextStyle(
                        color: Color(0xFF2ECC71),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeedbackSection(context, db, order),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmReceived(
    BuildContext context,
    DatabaseService db,
    String orderId,
  ) async {
    final confirmed = await db.confirmDeliveryReceived(orderId);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          confirmed
              ? 'Delivery confirmed!'
              : 'This delivery was already confirmed.',
        ),
        backgroundColor: confirmed ? Colors.green : Colors.orange,
      ),
    );
  }

  Widget _buildRiderInfo(
    BuildContext context,
    DatabaseService db,
    OrderModel order,
  ) {
    return StreamBuilder<UserModel?>(
      stream: db.getUser(order.riderId!),
      builder: (context, snapshot) {
        final rider = snapshot.data;
        final phone = rider?.phone ?? '';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rider Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('Name: ${rider?.name ?? order.riderId}'),
              if (phone.isNotEmpty) Text('Phone: $phone'),
              StreamBuilder<double>(
                stream: db.getRiderAverageRating(order.riderId!),
                builder: (context, ratingSnapshot) {
                  final rating = ratingSnapshot.data ?? 0;
                  if (rating == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Rating: ${rating.toStringAsFixed(1)} / 5'),
                  );
                },
              ),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: db.getRiderFeedback(order.riderId!),
                builder: (context, feedbackSnapshot) {
                  final feedback = feedbackSnapshot.data ?? [];
                  if (feedback.isEmpty) return const SizedBox.shrink();
                  final latest = feedback.first;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Recent feedback: ${latest['comment'] ?? ''}'),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: phone.isEmpty
                      ? null
                      : () => _callPhone(context, phone),
                  icon: const Icon(Icons.phone),
                  label: const Text('Call Rider'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedbackSection(
    BuildContext context,
    DatabaseService db,
    OrderModel order,
  ) {
    if (order.riderId == null) return const SizedBox.shrink();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: db.getOrderFeedback(order.orderId),
      builder: (context, snapshot) {
        final feedback = snapshot.data;
        if (feedback != null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Your feedback: ${feedback['rating']} / 5\n${feedback['comment'] ?? ''}',
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showRiderFeedbackDialog(context, db, order),
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Leave Rider Feedback'),
          ),
        );
      },
    );
  }

  Future<void> _showRiderFeedbackDialog(
    BuildContext context,
    DatabaseService db,
    OrderModel order,
  ) async {
    final controller = TextEditingController();
    var rating = 5;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rider Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    onPressed: () => setDialogState(() => rating = value),
                    icon: Icon(
                      value <= rating ? Icons.star : Icons.star_border,
                      color: Colors.orange,
                    ),
                  );
                }),
              ),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Comment'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await db.submitRiderFeedback(
                  orderId: order.orderId,
                  riderId: order.riderId!,
                  customerId: order.customerId,
                  rating: rating,
                  comment: controller.text.trim(),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }

  Future<void> _callPhone(BuildContext context, String phone) async {
    final launched = await launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open phone app')));
    }
  }

  Widget _buildStatusTimeline(String currentStatus) {
    final statuses = [
      {'key': 'pending', 'label': 'Pending'},
      {'key': 'assigned', 'label': 'Assigned'},
      {'key': 'picked_up', 'label': 'Picked Up'},
      {'key': 'in_transit', 'label': 'In Transit'},
      {'key': 'delivered', 'label': 'Delivered'},
    ];

    int currentIndex = statuses.indexWhere((s) => s['key'] == currentStatus);
    if (currentIndex == -1) currentIndex = 0;

    return Column(
      children: List.generate(statuses.length, (index) {
        final isCompleted = index <= currentIndex;
        final isCurrent = index == currentIndex;

        return Row(
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? const Color(0xFF2ECC71)
                        : Colors.grey[300],
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                if (index < statuses.length - 1)
                  Container(
                    width: 2,
                    height: 30,
                    color: isCompleted
                        ? const Color(0xFF2ECC71)
                        : Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Text(
              statuses[index]['label']!,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCompleted ? Colors.black : Colors.grey,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildInfoCard(
    String title,
    String address,
    String contact,
    String phone,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
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
          const SizedBox(height: 4),
          Text('Contact: $contact'),
          Text('Phone: $phone'),
        ],
      ),
    );
  }

  Widget _buildParcelCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Parcel Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Amount:'),
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
    );
  }

  String _shortOrderId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }
}
