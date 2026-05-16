import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create new order
  Future<void> createOrder(OrderModel order) async {
    await _firestore.collection('orders').doc(order.orderId).set(order.toMap());
    await _notifyRole(
      role: 'rider',
      title: 'New order available',
      body: 'Pickup: ${order.pickupAddress}',
      orderId: order.orderId,
    );
  }

  Future<bool> acceptOrder(String orderId, String riderId) async {
    final orderRef = _firestore.collection('orders').doc(orderId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      final data = snapshot.data();

      if (!snapshot.exists || data?['status'] != 'pending') {
        return false;
      }

      transaction.update(orderRef, {'riderId': riderId, 'status': 'assigned'});

      return true;
    });
  }

  Future<bool> acceptNearbyOrder(String orderId, String riderId) async {
    final accepted = await acceptOrder(orderId, riderId);
    if (accepted) {
      await _notifyUser(
        userId: riderId,
        title: 'Order accepted',
        body: 'You accepted order #${_shortOrderId(orderId)}',
        orderId: orderId,
      );
    }
    return accepted;
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final snapshot = await orderRef.get();
    final data = snapshot.data();

    await orderRef.update({'status': status});

    if (data == null) return;

    final order = OrderModel.fromMap(data);
    if (status == 'picked_up') {
      await _notifyUser(
        userId: order.customerId,
        title: 'Parcel picked up',
        body: 'Your parcel is now with the rider.',
        orderId: orderId,
      );
      await _notifyUser(
        userId: order.customerId,
        title: 'Estimated arrival time',
        body: _estimatedArrivalText(order),
        orderId: orderId,
      );
    } else if (status == 'in_transit') {
      await _notifyUser(
        userId: order.customerId,
        title: 'Estimated arrival time',
        body: _estimatedArrivalText(order),
        orderId: orderId,
      );
    }
  }

  Future<void> markAsDelivered(String orderId) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final snapshot = await orderRef.get();
    final data = snapshot.data();

    await orderRef.update({
      'status': 'delivered',
      'completedAt': DateTime.now().toIso8601String(),
    });

    if (data == null) return;

    final order = OrderModel.fromMap(data);
    await _notifyUser(
      userId: order.customerId,
      title: 'Order delivered',
      body: 'Please confirm that you received your parcel.',
      orderId: orderId,
    );
  }

  Future<bool> confirmDeliveryReceived(String orderId) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    String? riderId;
    double amount = 0;

    final confirmed = await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return false;

      final order = OrderModel.fromMap(data);
      if (order.status != 'delivered' ||
          order.customerAcknowledged ||
          order.riderId == null) {
        return false;
      }

      riderId = order.riderId;
      amount = order.amount;
      final now = DateTime.now();
      final earningsRef = _firestore
          .collection('users')
          .doc(order.riderId)
          .collection('earnings')
          .doc(_todayKey(now));

      transaction.update(orderRef, {
        'customerAcknowledged': true,
        'acknowledgedAt': now.toIso8601String(),
      });
      transaction.set(earningsRef, {
        'date': _todayKey(now),
        'amount': FieldValue.increment(order.amount),
        'deliveries': FieldValue.increment(1),
        'updatedAt': now.toIso8601String(),
      }, SetOptions(merge: true));

      return true;
    });

    if (confirmed && riderId != null) {
      await _notifyUser(
        userId: riderId!,
        title: 'Delivery confirmed',
        body: 'Rs. ${amount.toInt()} added to today\'s earnings.',
        orderId: orderId,
      );
    }

    return confirmed;
  }

  Stream<double> getTodayEarnings(String riderId) {
    return _firestore
        .collection('users')
        .doc(riderId)
        .collection('earnings')
        .doc(_todayKey())
        .snapshots()
        .map((doc) => ((doc.data()?['amount'] ?? 0) as num).toDouble());
  }

  Stream<UserModel?> getUser(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return UserModel.fromMap(data);
    });
  }

  Future<void> submitRiderFeedback({
    required String orderId,
    required String riderId,
    required String customerId,
    required int rating,
    required String comment,
  }) async {
    await _firestore.collection('rider_feedback').doc(orderId).set({
      'orderId': orderId,
      'riderId': riderId,
      'customerId': customerId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>?> getOrderFeedback(String orderId) {
    return _firestore
        .collection('rider_feedback')
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.data());
  }

  Stream<List<Map<String, dynamic>>> getRiderFeedback(String riderId) {
    return _firestore
        .collection('rider_feedback')
        .where('riderId', isEqualTo: riderId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map((doc) => doc.data()).toList();
          items.sort(
            (a, b) => _timestampMillis(
              b['createdAt'],
            ).compareTo(_timestampMillis(a['createdAt'])),
          );
          return items;
        });
  }

  Stream<double> getRiderAverageRating(String riderId) {
    return getRiderFeedback(riderId).map((items) {
      if (items.isEmpty) return 0;
      final total = items.fold<num>(
        0,
        (total, item) => total + ((item['rating'] ?? 0) as num),
      );
      return total / items.length;
    });
  }

  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              })
              .where((data) => data['dismissed'] != true)
              .toList();
          notifications.sort((a, b) {
            final aTime = a['createdAt'];
            final bTime = b['createdAt'];
            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }
            return 0;
          });
          return notifications;
        });
  }

  Stream<int> getUnreadNotificationCount(String userId) {
    return getUserNotifications(
      userId,
    ).map((items) => items.where((item) => item['read'] != true).length);
  }

  Future<void> markNotificationsRead(String userId) async {
    final unread = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> ensureMonthlySurveyNotification(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final user = await userRef.get();
    final hiddenUntil = _dateFromAny(user.data()?['surveyHiddenUntil']);
    if (hiddenUntil != null && hiddenUntil.isAfter(DateTime.now())) return;

    final existing = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'monthly_feedback')
        .where('dismissed', isEqualTo: false)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    await _firestore.collection('notifications').add({
      'userId': userId,
      'type': 'monthly_feedback',
      'title': 'Monthly app feedback',
      'body': 'Tell us how DropDost is working for you.',
      'read': false,
      'dismissed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> skipMonthlyFeedback(String userId, String notificationId) async {
    final hideUntil = DateTime.now().add(const Duration(days: 30));
    await _firestore.collection('users').doc(userId).update({
      'surveyHiddenUntil': Timestamp.fromDate(hideUntil),
    });
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
      'dismissed': true,
    });
  }

  Future<void> submitMonthlyFeedback({
    required String userId,
    required String notificationId,
    required String comment,
  }) async {
    final now = DateTime.now();
    await _firestore.collection('app_feedback').add({
      'userId': userId,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('users').doc(userId).update({
      'lastSurveySubmittedAt': Timestamp.fromDate(now),
      'surveyHiddenUntil': Timestamp.fromDate(
        now.add(const Duration(days: 30)),
      ),
    });
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
      'dismissed': true,
    });
  }

  // Get customer orders
  Stream<List<OrderModel>> getCustomerOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data()))
              .toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  // Get rider orders
  Stream<List<OrderModel>> getRiderOrders(String riderId) {
    return _firestore
        .collection('orders')
        .where('riderId', isEqualTo: riderId)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data()))
              .toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  // Get available orders (pending)
  Stream<List<OrderModel>> getAvailableOrders() {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data()))
              .toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  // Get single order
  Stream<OrderModel?> getOrder(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.exists ? OrderModel.fromMap(doc.data()!) : null);
  }

  Future<void> _notifyRole({
    required String role,
    required String title,
    required String body,
    required String orderId,
  }) async {
    final users = await _firestore
        .collection('users')
        .where('userType', isEqualTo: role)
        .get();

    final batch = _firestore.batch();
    for (final user in users.docs) {
      final ref = _firestore.collection('notifications').doc();
      batch.set(ref, {
        'userId': user.id,
        'role': role,
        'title': title,
        'body': body,
        'orderId': orderId,
        'dismissed': false,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> _notifyUser({
    required String userId,
    required String title,
    required String body,
    required String orderId,
  }) async {
    await _firestore.collection('notifications').add({
      'userId': userId,
      'title': title,
      'body': body,
      'orderId': orderId,
      'dismissed': false,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int _timestampMillis(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  String _estimatedArrivalText(OrderModel order) {
    final meters = _distanceBetween(
      order.pickupLat,
      order.pickupLng,
      order.deliveryLat,
      order.deliveryLng,
    );
    final minutes = ((meters / 1000) / 25 * 60).clamp(10, 90).round();
    return 'Estimated arrival time: $minutes minutes';
  }

  double _distanceBetween(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        _sin2(dLat / 2) +
        _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) * _sin2(dLng / 2);
    return earthRadius * 2 * _atan2Sqrt(a);
  }

  double _toRadians(double degrees) => degrees * 0.017453292519943295;
  double _sin2(double value) => math.sin(value) * math.sin(value);
  double _cos(double value) => math.cos(value);
  double _atan2Sqrt(double value) =>
      math.atan2(math.sqrt(value), math.sqrt(1 - value));

  String _todayKey([DateTime? date]) {
    final value = date ?? DateTime.now();
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _shortOrderId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }
}
