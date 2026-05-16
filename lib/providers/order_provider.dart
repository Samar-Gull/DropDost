import 'package:flutter/material.dart';
import '../models/order_model.dart';

class OrderProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  bool _isLoading = false;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;

  // Get orders for customer
  List<OrderModel> getCustomerOrders(String customerId) {
    return _orders.where((order) => order.customerId == customerId).toList();
  }

  // Get orders for rider
  List<OrderModel> getRiderOrders(String? riderId) {
    if (riderId == null) return [];
    return _orders.where((order) => order.riderId == riderId).toList();
  }

  // Get active orders
  List<OrderModel> getActiveOrders() {
    return _orders
        .where((order) =>
            order.status != 'delivered' && order.status != 'cancelled')
        .toList();
  }

  // Create order
  Future<void> createOrder(OrderModel order) async {
    _isLoading = true;
    notifyListeners();

    try {
      _orders.add(order);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Update order status - simplified
  void updateOrderStatus(String orderId, String newStatus) {
    final orderIndex = _orders.indexWhere((order) => order.orderId == orderId);
    if (orderIndex == -1) return;

    _orders[orderIndex] = _orders[orderIndex].copyWith(status: newStatus);
    notifyListeners();
  }

  // Assign an order to a rider
  void assignOrderToRider(String orderId, String riderId) {
    final orderIndex = _orders.indexWhere((order) => order.orderId == orderId);
    if (orderIndex == -1) return;

    _orders[orderIndex] = _orders[orderIndex].copyWith(
      riderId: riderId,
      status: 'assigned',
    );
    notifyListeners();
  }

  // Get order by ID
  OrderModel? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((order) => order.orderId == orderId);
    } catch (e) {
      return null;
    }
  }

  // Set orders
  void setOrders(List<OrderModel> orders) {
    _orders = orders;
    notifyListeners();
  }
}
