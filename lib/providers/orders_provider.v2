// lib/providers/orders_provider.dart
// Manages all order data: fetching, grouping by table, creating, updating.

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class OrdersProvider extends ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Returns only orders for a specific table (active status only)
  List<Order> ordersForTable(String tableNumber) {
    return _orders
        .where((o) =>
            o.tableNumber == tableNumber &&
            o.isActive)
        .toList();
  }

  // Returns total value of active orders for a table
  double tableTotalValue(String tableNumber) {
    return ordersForTable(tableNumber)
        .fold(0.0, (sum, o) => sum + o.total);
  }

  // Returns true if table has any active orders
  bool tableHasActiveOrders(String tableNumber) {
    return ordersForTable(tableNumber).isNotEmpty;
  }

  // Returns orders with no table number (online/takeaway)
  List<Order> get noTableOrders {
    return _orders
        .where((o) => o.tableNumber.isEmpty && o.isActive)
        .toList();
  }

  Future<void> fetchOrders(ApiService api, String vendorId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await api.getOrders(vendorId);
      _orders = fetched;
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load orders.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Order?> createOrder(
      ApiService api, Map<String, dynamic> orderData) async {
    try {
      final created = await api.createOrder(orderData);
      _orders.add(created);
      notifyListeners();
      return created;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateOrderStatus(
      ApiService api, String orderId, String status) async {
    try {
      final updated = await api.updateOrderStatus(orderId, status);
      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        _orders[idx] = updated;
        notifyListeners();
      }
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateOrder(
      ApiService api, String orderId, Map<String, dynamic> updates) async {
    try {
      final updated = await api.updateOrder(orderId, updates);
      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        _orders[idx] = updated;
        notifyListeners();
      }
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
