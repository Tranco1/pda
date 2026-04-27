// lib/models/models.dart
// Dart models matching the vpos TypeScript interfaces

class User {
  final String id;
  final String username;
  final String name;
  final String email;
  final String? telephone;
  final String usertype;
  final String? vendorId;
  final List<Permission> permissions;
  final String status;

  User({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    this.telephone,
    required this.usertype,
    this.vendorId,
    this.permissions = const [],
    required this.status,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      telephone: json['telephone'],
      usertype: json['usertype'] ?? 'customer',
      vendorId: json['vendorId'],
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((p) => Permission.fromJson(p))
              .toList() ??
          [],
      status: json['status'] ?? 'active',
    );
  }
}

class Permission {
  final String module;
  final List<String> actions;

  Permission({required this.module, required this.actions});

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      module: json['module'] ?? '',
      actions: List<String>.from(json['actions'] ?? []),
    );
  }
}

class Vendor {
  final String id;
  final String vendorId;
  final String name;
  final String? businessName;
  final int? numberOfTables;
  final VendorSettings settings;
  final String status;

  Vendor({
    required this.id,
    required this.vendorId,
    required this.name,
    this.businessName,
    this.numberOfTables,
    required this.settings,
    required this.status,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['_id'] ?? json['id'] ?? '',
      vendorId: json['vendorId'] ?? '',
      name: json['name'] ?? '',
      businessName: json['businessName'],
      numberOfTables: json['numberOfTables'],
      settings: VendorSettings.fromJson(json['settings'] ?? {}),
      status: json['status'] ?? 'active',
    );
  }
}

class VendorSettings {
  final String currency;
  final double taxRate;
  final String timezone;
  final String? receiptFooter;
  final String? logoUrl;

  VendorSettings({
    required this.currency,
    required this.taxRate,
    required this.timezone,
    this.receiptFooter,
    this.logoUrl,
  });

  factory VendorSettings.fromJson(Map<String, dynamic> json) {
    return VendorSettings(
      currency: json['currency'] ?? 'GBP',
      taxRate: (json['taxRate'] ?? 0).toDouble(),
      timezone: json['timezone'] ?? 'Europe/London',
      receiptFooter: json['receiptFooter'],
      logoUrl: json['logoUrl'],
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String vendorId;
  final String tableNumber;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final OrderPayment payment;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;

  Order({
    required this.id,
    required this.orderNumber,
    required this.vendorId,
    required this.tableNumber,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.payment,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  bool get isActive =>
      status == OrderStatus.pending ||
      status == OrderStatus.confirmed ||
      status == OrderStatus.processing ||
      status == OrderStatus.held;

  bool get isEditable =>
      status == OrderStatus.pending ||
      status == OrderStatus.held;

  bool get hasTable => tableNumber.isNotEmpty;

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] ?? json['id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      vendorId: json['vendorId'] ?? '',
      tableNumber: json['tableNumber'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromJson(i))
              .toList() ??
          [],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      payment: OrderPayment.fromJson(json['payment'] ?? {}),
      status: OrderStatus.fromString(json['status'] ?? 'pending'),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderNumber': orderNumber,
      'vendorId': vendorId,
      'tableNumber': tableNumber,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'payment': payment.toJson(),
      'status': status.value,
    };
  }
}

class OrderItem {
  final String productId;
  final String name;
  final String? shortDesc;
  final double price;
  int quantity;
  final double subtotal;
  final double taxAmount;
  final String? variant;

  OrderItem({
    required this.productId,
    required this.name,
    this.shortDesc,
    required this.price,
    required this.quantity,
    required this.subtotal,
    required this.taxAmount,
    this.variant,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] ?? '',
      name: json['name'] ?? '',
      shortDesc: json['shortDesc'],
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      taxAmount: (json['taxAmount'] ?? 0).toDouble(),
      variant: json['variant'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'shortDesc': shortDesc,
      'price': price,
      'quantity': quantity,
      'subtotal': price * quantity,
      'taxAmount': taxAmount,
      'variant': variant,
    };
  }
}

class OrderPayment {
  final String method;
  final String status;
  final double paidAmount;
  final double changeDue;

  OrderPayment({
    required this.method,
    required this.status,
    required this.paidAmount,
    required this.changeDue,
  });

  factory OrderPayment.fromJson(Map<String, dynamic> json) {
    return OrderPayment(
      method: json['method'] ?? 'cash',
      status: json['status'] ?? 'pending',
      paidAmount: (json['paidAmount'] ?? 0).toDouble(),
      changeDue: (json['changeDue'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'status': status,
      'paidAmount': paidAmount,
      'changeDue': changeDue,
    };
  }
}

enum OrderStatus {
  pending,
  confirmed,
  processing,
  completed,
  cancelled,
  held,
  refunded;

  static OrderStatus fromString(String s) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => OrderStatus.pending,
    );
  }

  String get value => name;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.held:
        return 'Held';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }
}

class Product {
  final String id;
  final String vendorId;
  final String name;
  final double price;
  final double? costPrice;
  final int stock;
  final String? description;
  final String? shortDesc;
  final String sku;
  final List<ProductVariant> variants;
  final bool isActive;
  final String? categoryId;

  Product({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.price,
    this.costPrice,
    required this.stock,
    this.description,
    this.shortDesc,
    required this.sku,
    this.variants = const [],
    required this.isActive,
    this.categoryId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] ?? json['id'] ?? '',
      vendorId: json['vendorId'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      costPrice: json['costPrice'] != null
          ? (json['costPrice']).toDouble()
          : null,
      stock: json['stock'] ?? 0,
      description: json['description'],
      shortDesc: json['shortDesc'],
      sku: json['sku'] ?? '',
      variants: (json['variants'] as List<dynamic>?)
              ?.map((v) => ProductVariant.fromJson(v))
              .toList() ??
          [],
      isActive: json['isActive'] ?? true,
      categoryId: json['categoryId'],
    );
  }
}

class ProductVariant {
  final String name;
  final double price;
  final int stock;
  final String sku;

  ProductVariant({
    required this.name,
    required this.price,
    required this.stock,
    required this.sku,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      stock: json['stock'] ?? 0,
      sku: json['sku'] ?? '',
    );
  }
}

class AuthResponse {
  final String token;
  final User user;
  final Vendor vendor;

  AuthResponse({
    required this.token,
    required this.user,
    required this.vendor,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] ?? '',
      user: User.fromJson(json['user']),
      vendor: Vendor.fromJson(json['vendor']),
    );
  }
}
