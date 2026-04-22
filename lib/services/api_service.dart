// lib/services/api_service.dart
// All network calls go here. The app talks to YOUR backend API,
// never directly to MongoDB Atlas or AWS S3.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  // ---------------------------------------------------------------
  // CONFIGURE: Point this to your backend server URL.
  // In development: http://localhost:3000
  // In production: https://your-api.yourdomain.com
  // ---------------------------------------------------------------
//  static const String _baseUrl = 'https://your-api.yourdomain.com';
  static const String _baseUrl = 'http://localhost:3000';

  final String? _authToken;

  ApiService({String? authToken}) : _authToken = authToken;

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final message = body['message'] ?? body['error'] ?? 'Request failed';
    throw ApiException(message, statusCode: response.statusCode);
  }

  // ─── Auth ──────────────────────────────────────────────────────

  Future<AuthResponse> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = await _handleResponse(response);
    return AuthResponse.fromJson(data);
  }

  // ─── Vendor ────────────────────────────────────────────────────

  Future<Vendor> getVendor(String vendorId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/vendors/$vendorId'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    return Vendor.fromJson(data['vendor'] ?? data);
  }

  // ─── Orders ────────────────────────────────────────────────────

  /// Fetch all active orders for a vendor
  Future<List<Order>> getOrders(String vendorId, {String? status}) async {
    final queryParams = <String, String>{'vendorId': vendorId};
    if (status != null) queryParams['status'] = status;

    final uri = Uri.parse('$_baseUrl/api/orders')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);
    final data = await _handleResponse(response);

    final List<dynamic> ordersJson = data['orders'] ?? data['data'] ?? [];
    return ordersJson.map((o) => Order.fromJson(o)).toList();
  }

  /// Fetch orders for a specific table
  Future<List<Order>> getTableOrders(
      String vendorId, String tableNumber) async {
    final uri = Uri.parse('$_baseUrl/api/orders').replace(queryParameters: {
      'vendorId': vendorId,
      'tableNumber': tableNumber,
      'status': 'active', // active = pending,confirmed,processing,held
    });
    final response = await http.get(uri, headers: _headers);
    final data = await _handleResponse(response);

    final List<dynamic> ordersJson = data['orders'] ?? data['data'] ?? [];
    return ordersJson.map((o) => Order.fromJson(o)).toList();
  }

  /// Create a new order
  Future<Order> createOrder(Map<String, dynamic> orderData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/orders'),
      headers: _headers,
      body: jsonEncode(orderData),
    );
    final data = await _handleResponse(response);
    return Order.fromJson(data['order'] ?? data);
  }

  /// Update order status
  Future<Order> updateOrderStatus(String orderId, String status) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/api/orders/$orderId'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    final data = await _handleResponse(response);
    return Order.fromJson(data['order'] ?? data);
  }

  /// Update full order (items, table, etc.)
  Future<Order> updateOrder(
      String orderId, Map<String, dynamic> updates) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/orders/$orderId'),
      headers: _headers,
      body: jsonEncode(updates),
    );
    final data = await _handleResponse(response);
    return Order.fromJson(data['order'] ?? data);
  }

  // ─── Products ──────────────────────────────────────────────────

  Future<List<Product>> getProducts(String vendorId,
      {String? categoryId}) async {
    final queryParams = <String, String>{
      'vendorId': vendorId,
      'isActive': 'true',
    };
    if (categoryId != null) queryParams['categoryId'] = categoryId;

    final uri = Uri.parse('$_baseUrl/api/products')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);
    final data = await _handleResponse(response);

    final List<dynamic> productsJson = data['products'] ?? data['data'] ?? [];
    return productsJson.map((p) => Product.fromJson(p)).toList();
  }
}
