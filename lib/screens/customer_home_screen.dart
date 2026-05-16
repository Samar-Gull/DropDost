import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../providers/database_service.dart';
import '../widgets/notification_button.dart';
import 'track_order_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final dbService = Provider.of<DatabaseService>(context);
    final userId = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DropDost'),
        actions: [
          NotificationButton(userId: authService.currentUser?.uid),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${authService.currentUser?.name ?? 'User'}!',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/create-order'),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_circle_outline,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEW ORDER',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Send a parcel',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (userId == null)
              const Center(child: Text('Please sign in again.'))
            else
              StreamBuilder<List<OrderModel>>(
                stream: dbService.getCustomerOrders(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final orders = snapshot.data ?? [];
                  final pendingOrders = orders
                      .where((order) => order.status == 'pending')
                      .toList();

                  if (orders.isEmpty) {
                    return _buildEmptyState('No orders yet');
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderSection(
                        context,
                        title: 'Pending Orders',
                        orders: pendingOrders,
                        emptyText: 'No pending orders',
                      ),
                      const SizedBox(height: 32),
                      _buildOrderSection(
                        context,
                        title: 'Recent Orders',
                        orders: orders,
                        emptyText: 'No recent orders',
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSection(
    BuildContext context, {
    required String title,
    required List<OrderModel> orders,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (orders.isEmpty)
          _buildEmptyState(emptyText, compact: true)
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            itemBuilder: (context, index) => OrderCard(order: orders[index]),
          ),
      ],
    );
  }

  Widget _buildEmptyState(String message, {bool compact = false}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 40),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final OrderModel order;

  const OrderCard({super.key, required this.order});

  Color _getStatusColor() {
    switch (order.status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
      case 'picked_up':
      case 'in_transit':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TrackOrderScreen(orderId: order.orderId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.orderId.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.getStatusDisplay(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.pickupAddress,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rs. ${order.amount.toInt()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TrackOrderScreen(orderId: order.orderId),
                        ),
                      );
                    },
                    child: const Text('Track'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
