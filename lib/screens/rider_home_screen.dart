import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../providers/database_service.dart';
import '../widgets/notification_button.dart';
import 'active_delivery_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  static const double _nearbyRadiusMeters = 10000;
  static const Set<String> _activeStatuses = {
    'assigned',
    'picked_up',
    'in_transit',
  };

  Position? _riderPosition;
  bool _isLoadingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadRiderLocation();
  }

  Future<void> _loadRiderLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please enable location services');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required');
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      setState(() => _riderPosition = position);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  double? _distanceToPickup(OrderModel order) {
    final riderPosition = _riderPosition;
    if (riderPosition == null) return null;

    return Geolocator.distanceBetween(
      riderPosition.latitude,
      riderPosition.longitude,
      order.pickupLat,
      order.pickupLng,
    );
  }

  List<OrderModel> _nearbyOrders(List<OrderModel> orders) {
    final nearbyOrders = orders.where((order) {
      final distance = _distanceToPickup(order);
      return distance != null && distance <= _nearbyRadiusMeters;
    }).toList();

    nearbyOrders.sort(
      (a, b) => _distanceToPickup(a)!.compareTo(_distanceToPickup(b)!),
    );

    return nearbyOrders;
  }

  Future<void> _acceptOrder(
    DatabaseService dbService,
    OrderModel order,
    String riderId,
  ) async {
    final distance = _distanceToPickup(order);
    if (distance == null || distance > _nearbyRadiusMeters) {
      _showSnackBar('Order is outside your nearby delivery radius');
      return;
    }

    final accepted = await dbService.acceptNearbyOrder(order.orderId, riderId);
    if (!mounted) return;

    _showSnackBar(
      accepted ? 'Order accepted!' : 'This order is no longer available',
      backgroundColor: accepted ? Colors.green : Colors.orange,
    );
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    });

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      _showSnackBar('Could not open map');
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  bool _isActiveDelivery(OrderModel order) {
    return _activeStatuses.contains(order.status);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context);
    final riderId = authProvider.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DropDost Rider'),
        actions: [
          NotificationButton(userId: riderId),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: riderId == null
            ? const Center(child: Text('Please sign in again.'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 24),
                  _buildDashboard(dbService, riderId),
                  const SizedBox(height: 32),
                  _buildAvailableOrders(dbService, riderId),
                  const SizedBox(height: 32),
                  _buildActiveDeliveries(dbService, riderId),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2ECC71),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          const Text(
            'Available',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _loadRiderLocation,
            child: const Text(
              'Refresh GPS',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(DatabaseService dbService, String riderId) {
    return StreamBuilder<List<OrderModel>>(
      stream: dbService.getRiderOrders(riderId),
      builder: (context, orderSnapshot) {
        final riderOrders = orderSnapshot.data ?? [];
        final acceptedOrders = riderOrders
            .where((order) => order.status == 'assigned')
            .length;
        final pendingDeliveries = riderOrders.where(_isActiveDelivery).length;

        return StreamBuilder<double>(
          stream: dbService.getTodayEarnings(riderId),
          builder: (context, earningsSnapshot) {
            final todayEarnings = earningsSnapshot.data ?? 0;

            return Row(
              children: [
                Expanded(
                  child: _DashboardCard(
                    label: 'Today\'s Earnings',
                    value: 'Rs. ${todayEarnings.toInt()}',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DashboardCard(
                    label: 'Accepted Orders',
                    value: acceptedOrders.toString(),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DashboardCard(
                    label: 'Pending Deliveries',
                    value: pendingDeliveries.toString(),
                    color: const Color(0xFF2ECC71),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAvailableOrders(DatabaseService dbService, String riderId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Orders Nearby',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_isLoadingLocation)
          const Center(child: CircularProgressIndicator())
        else if (_riderPosition == null)
          _LocationPrompt(
            message: _locationError ?? 'Enable location to see nearby orders',
            onRetry: _loadRiderLocation,
          )
        else
          StreamBuilder<List<OrderModel>>(
            stream: dbService.getAvailableOrders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final nearbyOrders = _nearbyOrders(snapshot.data ?? []);
              if (nearbyOrders.isEmpty) {
                return _EmptyList(
                  message: 'No nearby orders within 10 km',
                  padding: 40,
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: nearbyOrders.length,
                itemBuilder: (context, index) {
                  final order = nearbyOrders[index];
                  final distance = _distanceToPickup(order);

                  return AvailableOrderCard(
                    order: order,
                    distanceMeters: distance,
                    onViewMap: () =>
                        _openMap(order.deliveryLat, order.deliveryLng),
                    onAccept: () => _acceptOrder(dbService, order, riderId),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildActiveDeliveries(DatabaseService dbService, String riderId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Deliveries',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<OrderModel>>(
          stream: dbService.getRiderOrders(riderId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final activeOrders = (snapshot.data ?? [])
                .where(_isActiveDelivery)
                .toList();

            if (activeOrders.isEmpty) {
              return const _EmptyList(message: 'No active deliveries');
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeOrders.length,
              itemBuilder: (context, index) {
                final order = activeOrders[index];
                return ActiveOrderCard(
                  order: order,
                  onViewMap: () =>
                      _openMap(order.deliveryLat, order.deliveryLng),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DashboardCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _LocationPrompt extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LocationPrompt({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 56,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.my_location),
              label: const Text('Use My Location'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  final String message;
  final double padding;

  const _EmptyList({required this.message, this.padding = 20});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Text(message, style: TextStyle(color: Colors.grey[600])),
      ),
    );
  }
}

class AvailableOrderCard extends StatelessWidget {
  final OrderModel order;
  final double? distanceMeters;
  final VoidCallback onAccept;
  final VoidCallback onViewMap;

  const AvailableOrderCard({
    super.key,
    required this.order,
    required this.distanceMeters,
    required this.onAccept,
    required this.onViewMap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${_shortOrderId(order.orderId)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
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
            if (distanceMeters != null) ...[
              const SizedBox(height: 6),
              Text(
                '${_formatDistance(distanceMeters!)} from pickup',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showDetails(context, order),
                    child: const Text('DETAILS'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('MAP'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    child: const Text('ACCEPT'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Order Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pickup: ${order.pickupAddress}'),
            Text('Contact: ${order.pickupContact}'),
            Text('Phone: ${order.pickupPhone}'),
            const SizedBox(height: 12),
            Text('Delivery: ${order.deliveryAddress}'),
            Text('Contact: ${order.deliveryContact}'),
            Text('Phone: ${order.deliveryPhone}'),
            const SizedBox(height: 12),
            Text('Size: ${order.parcelSize.toUpperCase()}'),
            if (order.description.isNotEmpty)
              Text('Description: ${order.description}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class ActiveOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onViewMap;

  const ActiveOrderCard({
    super.key,
    required this.order,
    required this.onViewMap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ActiveDeliveryScreen(orderId: order.orderId),
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
                    'Order #${_shortOrderId(order.orderId)}',
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
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.getStatusDisplay(),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Pickup: ${order.pickupAddress}'),
              const SizedBox(height: 4),
              Text('Delivery: ${order.deliveryAddress}'),
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
                  TextButton.icon(
                    onPressed: onViewMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Map'),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _shortOrderId(String id) {
  if (id.length <= 8) return id;
  return id.substring(0, 8);
}

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
