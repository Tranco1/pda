// lib/services/api_service.dart

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
  static const String _baseUrl = 'http://localhost:3000';
//  static const String _baseUrl = 'https://vapi-yj8f.onrender.com';

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
    return Vendor.fromJson(data['data'] ?? data['vendor'] ?? data);
  }

  // ─── Orders ────────────────────────────────────────────────────

  Future<List<Order>> getOrders(String vendorId, {String? status}) async {
    final uri = Uri.parse('$_baseUrl/api/orders/vendor/$vendorId/tableNumber');
    final response = await http.get(uri, headers: _headers);
    final body = await _handleResponse(response);
    final data = body['data'] ?? body;
    final ordersRaw = data['orders'];
    if (ordersRaw == null) return [];
    return (ordersRaw as List<dynamic>)
        .map((o) => Order.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  Future<List<Order>> getNoTableOrders(String vendorId) async {
    final uri = Uri.parse('$_baseUrl/api/orders/vendor/$vendorId/OnlineNoTable');
    final response = await http.get(uri, headers: _headers);
    final body = await _handleResponse(response);
    final data = body['data'] ?? body;
    final ordersRaw = data['orders'];
    if (ordersRaw == null) return [];
    return (ordersRaw as List<dynamic>)
        .map((o) => Order.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  Future<List<Order>> getTableOrders(String vendorId, String tableNumber) async {
    final uri = Uri.parse('$_baseUrl/api/orders/vendor/$vendorId/tableNumber')
        .replace(queryParameters: {'tableNumber': tableNumber});
    final response = await http.get(uri, headers: _headers);
    final body = await _handleResponse(response);
    final data = body['data'] ?? body;
    final ordersRaw = data['orders'];
    if (ordersRaw == null) return [];
    return (ordersRaw as List<dynamic>)
        .map((o) => Order.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  Future<Order> createOrder(String vendorId, Map<String, dynamic> orderData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/orders/vendor/$vendorId'),
      headers: _headers,
      body: jsonEncode(orderData),
    );
    final data = await _handleResponse(response);
    return Order.fromJson(data['order'] ?? data['data'] ?? data);
  }

  Future<Order> updateOrderStatus(String vendorId, String orderId, String status) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/api/orders/vendor/$vendorId/$orderId/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    final data = await _handleResponse(response);
    return Order.fromJson(data['order'] ?? data['data'] ?? data);
  }

  Future<Order> updateOrder(String vendorId, String orderId, Map<String, dynamic> updates) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/orders/vendor/$vendorId/$orderId'),
      headers: _headers,
      body: jsonEncode(updates),
    );
    final data = await _handleResponse(response);
    return Order.fromJson(data['order'] ?? data['data'] ?? data);
  }

  // ─── Categories ────────────────────────────────────────────────

  Future<List<ProductCategory>> getCategories(String vendorId) async {
    final uri = Uri.parse('$_baseUrl/api/categories/tree')
        .replace(queryParameters: {'vendorId': vendorId});
    final response = await http.get(uri, headers: _headers);
    final body = await _handleResponse(response);
    // Response: { success: true, data: [ ...categories ] }
    final raw = body['data'];
    if (raw == null || raw is! List) return [];
    return (raw)
        .map((c) => ProductCategory.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  // ─── Products ──────────────────────────────────────────────────
  // Fetches ALL pages so the full product list is available client-side.
  // Your API returns 20/page by default; we request 100 to minimise trips.

  Future<List<Product>> getProducts(String vendorId) async {
    final allProducts = <Product>[];
    int page = 1;
    int totalPages = 1;

    do {
      final uri = Uri.parse('$_baseUrl/api/products/vendor/$vendorId')
          .replace(queryParameters: {'page': '$page', 'limit': '100'});

      final response = await http.get(uri, headers: _headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('Failed to load products',
            statusCode: response.statusCode);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      // Shape: { success, data: { products: [], pagination: { pages } } }
      final dataField = decoded['data'];
      if (dataField == null || dataField is! Map) break;

      final productsRaw = (dataField as Map<String, dynamic>)['products'];
      if (productsRaw == null || productsRaw is! List) break;

      allProducts.addAll((productsRaw)
          .map((p) => Product.fromJson(p as Map<String, dynamic>)));

      final pagination = dataField['pagination'];
      if (pagination is Map) {
        totalPages = (pagination['pages'] ?? 1) as int;
      }
      page++;
    } while (page <= totalPages);

    return allProducts;
  }
}
