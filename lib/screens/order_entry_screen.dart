// lib/screens/order_entry_screen.dart
// Create a new order or edit an existing one.
// Allows the user to clear the table number (making it an online/takeaway order).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class OrderEntryScreen extends StatefulWidget {
  final String tableNumber;
  final Order? existingOrder;

  const OrderEntryScreen({
    super.key,
    required this.tableNumber,
    this.existingOrder,
  });

  @override
  State<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends State<OrderEntryScreen> {
  late TextEditingController _tableController;
  List<OrderItem> _items = [];
  List<Product> _products = [];
  bool _loadingProducts = false;
  String _productSearch = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tableController =
        TextEditingController(text: widget.existingOrder?.tableNumber ?? widget.tableNumber);
    if (widget.existingOrder != null) {
      _items = List.from(widget.existingOrder!.items);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProducts());
  }

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final auth = context.read<AuthProvider>();
    if (auth.vendor == null) return;
    setState(() => _loadingProducts = true);
    try {
      final products =
          await auth.apiService.getProducts(auth.vendor!.id);
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    } catch (e) {
      setState(() => _loadingProducts = false);
    }
  }

  List<Product> get _filteredProducts {
    if (_productSearch.isEmpty) return _products;
    final q = _productSearch.toLowerCase();
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q))
        .toList();
  }

  void _addProduct(Product product, {String? variant, double? variantPrice}) {
    final price = variantPrice ?? product.price;
    final existingIdx = _items.indexWhere(
      (item) =>
          item.productId == product.id &&
          item.variant == (variant ?? ''),
    );

    setState(() {
      if (existingIdx != -1) {
        _items[existingIdx].quantity++;
      } else {
        _items.add(OrderItem(
          productId: product.id,
          name: product.name,
          shortDesc: product.shortDesc,
          price: price,
          quantity: 1,
          subtotal: price,
          taxAmount: 0, // calculated server-side
          variant: variant,
        ));
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _adjustQuantity(int index, int delta) {
    setState(() {
      _items[index].quantity += delta;
      if (_items[index].quantity <= 0) {
        _items.removeAt(index);
      }
    });
  }

  double get _subtotal =>
      _items.fold(0, (sum, i) => sum + i.price * i.quantity);

  double _tax(double taxRate) => _subtotal * (taxRate / 100);

  double _total(double taxRate) => _subtotal + _tax(taxRate);

  Future<void> _saveOrder() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final orders = context.read<OrdersProvider>();
    final vendor = auth.vendor;
    if (vendor == null) return;

    setState(() => _isSaving = true);

    final taxRate = vendor.settings.taxRate;
    final sub = _subtotal;
    final tax = _tax(taxRate);
    final total = _total(taxRate);
    final tableNum = _tableController.text.trim();

    final orderData = {
      'vendorId': vendor.id,
      'tableNumber': tableNum,
      'items': _items
          .map((i) => {
                'productId': i.productId,
                'name': i.name,
                'shortDesc': i.shortDesc,
                'price': i.price,
                'quantity': i.quantity,
                'subtotal': i.price * i.quantity,
                'taxAmount': (i.price * i.quantity) * (taxRate / 100),
                'variant': i.variant,
              })
          .toList(),
      'subtotal': sub,
      'tax': tax,
      'total': total,
      'payment': {
        'method': 'cash',
        'status': 'pending',
        'paidAmount': 0,
        'changeDue': 0,
      },
      'customer': {},
      'status': 'pending',
    };

    bool success;
    if (widget.existingOrder != null) {
      success = await orders.updateOrder(
          auth.apiService, widget.existingOrder!.id, orderData);
    } else {
      final created = await orders.createOrder(auth.apiService, orderData);
      success = created != null;
    }

    setState(() => _isSaving = false);

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(orders.error ?? 'Failed to save order')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vendor = auth.vendor;
    final taxRate = vendor?.settings.taxRate ?? 0;
    final currency = vendor?.settings.currency == 'GBP' ? '£' : '\$';
    final fmt = NumberFormat.currency(symbol: currency, decimalDigits: 2);
    final theme = Theme.of(context);
    final isEditing = widget.existingOrder != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Order' : 'New Order'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _saveOrder,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Table number field ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextFormField(
              controller: _tableController,
              decoration: InputDecoration(
                labelText: 'Table number',
                hintText: 'Leave empty for online/takeaway',
                prefixIcon: const Icon(Icons.table_restaurant_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: _tableController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear table (online/takeaway)',
                        onPressed: () => setState(
                            () => _tableController.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          const SizedBox(height: 12),

          // ── Main body: product search + order items ──────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product list (left/top half on smaller screens)
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search products',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) =>
                              setState(() => _productSearch = v),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _loadingProducts
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                itemCount: _filteredProducts.length,
                                itemBuilder: (ctx, i) {
                                  final product = _filteredProducts[i];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    dense: true,
                                    title: Text(product.name,
                                        style: const TextStyle(fontSize: 14)),
                                    subtitle: product.shortDesc != null
                                        ? Text(product.shortDesc!,
                                            style:
                                                const TextStyle(fontSize: 12))
                                        : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          fmt.format(product.price),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Show variant picker if product has variants
                                        if (product.variants.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(
                                                Icons.expand_circle_down_outlined,
                                                size: 20),
                                            onPressed: () =>
                                                _showVariantPicker(
                                                    context, product, fmt),
                                          )
                                        else
                                          IconButton(
                                            icon: const Icon(
                                                Icons.add_circle_outline,
                                                size: 20),
                                            onPressed: () =>
                                                _addProduct(product),
                                          ),
                                      ],
                                    ),
                                    onTap: product.variants.isEmpty
                                        ? () => _addProduct(product)
                                        : null,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                VerticalDivider(
                    width: 1, color: theme.colorScheme.outlineVariant),

                // Order items (right side)
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            Text('Order',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text(
                              '${_items.length} item${_items.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _items.isEmpty
                            ? Center(
                                child: Text(
                                  'Add items from\nthe product list',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                itemCount: _items.length,
                                itemBuilder: (ctx, i) {
                                  final item = _items[i];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    elevation: 0,
                                    color: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withOpacity(0.5),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      child: Row(
                                        children: [
                                          // Quantity controls
                                          IconButton(
                                            icon: const Icon(
                                                Icons.remove_circle_outline,
                                                size: 20),
                                            onPressed: () =>
                                                _adjustQuantity(i, -1),
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6),
                                            child: Text(
                                              '${item.quantity}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.add_circle_outline,
                                                size: 20),
                                            onPressed: () =>
                                                _adjustQuantity(i, 1),
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(item.name,
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                                if (item.variant != null &&
                                                    item.variant!.isNotEmpty)
                                                  Text(item.variant!,
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurfaceVariant)),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            fmt.format(
                                                item.price * item.quantity),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close,
                                                size: 16),
                                            onPressed: () => _removeItem(i),
                                            padding: const EdgeInsets.only(
                                                left: 4),
                                            constraints:
                                                const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      // ── Totals ──────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.5),
                          border: Border(
                            top: BorderSide(
                                color: theme.colorScheme.outlineVariant),
                          ),
                        ),
                        child: Column(
                          children: [
                            _TotalRow(
                                label: 'Subtotal',
                                value: fmt.format(_subtotal)),
                            _TotalRow(
                                label: 'Tax (${taxRate.toStringAsFixed(0)}%)',
                                value: fmt.format(_tax(taxRate))),
                            const Divider(height: 16),
                            _TotalRow(
                              label: 'Total',
                              value: fmt.format(_total(taxRate)),
                              bold: true,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isSaving ? null : _saveOrder,
                                child: Text(isEditing
                                    ? 'Update order'
                                    : 'Place order'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVariantPicker(
      BuildContext context, Product product, NumberFormat fmt) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Select variant',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            ...product.variants.map((variant) => ListTile(
                  title: Text(variant.name),
                  trailing: Text(fmt.format(variant.price),
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addProduct(product,
                        variant: variant.name,
                        variantPrice: variant.price);
                  },
                )),
            // Also allow base product
            ListTile(
              title: const Text('No variant'),
              trailing: Text(fmt.format(product.price),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _addProduct(product);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _TotalRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
