class OrderModel {
  final String orderId;
  final String customerId;
  final String? riderId;

  // Pickup details
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String pickupContact;
  final String pickupPhone;

  // Delivery details
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  final String deliveryContact;
  final String deliveryPhone;

  // Parcel details
  final String parcelSize; // 'small', 'medium', 'large'
  final String description;
  final double amount;

  // Status
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool customerAcknowledged;
  final DateTime? acknowledgedAt;

  OrderModel({
    required this.orderId,
    required this.customerId,
    this.riderId,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupContact,
    required this.pickupPhone,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.deliveryContact,
    required this.deliveryPhone,
    required this.parcelSize,
    required this.description,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.customerAcknowledged = false,
    this.acknowledgedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerId': customerId,
      'riderId': riderId,
      'pickupAddress': pickupAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'pickupContact': pickupContact,
      'pickupPhone': pickupPhone,
      'deliveryAddress': deliveryAddress,
      'deliveryLat': deliveryLat,
      'deliveryLng': deliveryLng,
      'deliveryContact': deliveryContact,
      'deliveryPhone': deliveryPhone,
      'parcelSize': parcelSize,
      'description': description,
      'amount': amount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'customerAcknowledged': customerAcknowledged,
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
    };
  }

  OrderModel copyWith({
    String? orderId,
    String? customerId,
    String? riderId,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? pickupContact,
    String? pickupPhone,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? deliveryContact,
    String? deliveryPhone,
    String? parcelSize,
    String? description,
    double? amount,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
    bool? customerAcknowledged,
    DateTime? acknowledgedAt,
  }) {
    return OrderModel(
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      riderId: riderId ?? this.riderId,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      pickupContact: pickupContact ?? this.pickupContact,
      pickupPhone: pickupPhone ?? this.pickupPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLat: deliveryLat ?? this.deliveryLat,
      deliveryLng: deliveryLng ?? this.deliveryLng,
      deliveryContact: deliveryContact ?? this.deliveryContact,
      deliveryPhone: deliveryPhone ?? this.deliveryPhone,
      parcelSize: parcelSize ?? this.parcelSize,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      customerAcknowledged: customerAcknowledged ?? this.customerAcknowledged,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }

  String getStatusDisplay() {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'accepted':
        return 'Accepted';
      case 'picked_up':
        return 'Picked Up';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      orderId: map['orderId'] ?? '',
      customerId: map['customerId'] ?? '',
      riderId: map['riderId'],
      pickupAddress: map['pickupAddress'] ?? '',
      pickupLat: map['pickupLat'] ?? 0.0,
      pickupLng: map['pickupLng'] ?? 0.0,
      pickupContact: map['pickupContact'] ?? '',
      pickupPhone: map['pickupPhone'] ?? '',
      deliveryAddress: map['deliveryAddress'] ?? '',
      deliveryLat: map['deliveryLat'] ?? 0.0,
      deliveryLng: map['deliveryLng'] ?? 0.0,
      deliveryContact: map['deliveryContact'] ?? '',
      deliveryPhone: map['deliveryPhone'] ?? '',
      parcelSize: map['parcelSize'] ?? 'small',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      createdAt: DateTime.parse(map['createdAt']),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
      customerAcknowledged: map['customerAcknowledged'] ?? false,
      acknowledgedAt: map['acknowledgedAt'] != null
          ? DateTime.parse(map['acknowledgedAt'])
          : null,
    );
  }
}
