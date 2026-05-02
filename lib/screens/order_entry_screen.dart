// lib/screens/order_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../models/models.dart';

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
  List<ProductCategory> _categories = [];
  bool _loadingProducts = true;
  String? _loadCategoryError;
  String _productSearch = '';

  // Two-level selection
  ProductCategory? _selectedParent;   // selected parent category
  ProductCategory? _selectedChild;    // selected subcategory (optional)

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tableController = TextEditingController(
        text: widget.existingOrder?.tableNumber ?? widget.tableNumber);
    if (widget.existingOrder != null) {
      _items = widget.existingOrder!.items
          .map((i) => OrderItem(
                productId: i.productId,
                name: i.name,
                shortDesc: i.shortDesc,
                price: i.price,
                quantity: i.quantity,
                subtotal: i.subtotal,
                taxAmount: i.taxAmount,
                variant: i.variant,
                comment: i.comment,
              ))
          .toList();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.vendor == null) {
      setState(() => _loadCategoryError = 'No vendor loaded');
      return;
    }
    final vendorId = auth.vendor!.id;
    setState(() {
      _loadingProducts = true;
      _loadCategoryError = null;
    });

    try {
      final cats = await auth.apiService.getCategories(vendorId);
      if (mounted) setState(() => _categories = cats);
    } catch (e) {
      if (mounted) setState(() => _loadCategoryError = 'Categories: $e');
    }

    try {
      final prods = await auth.apiService.getProducts(vendorId);
      if (mounted) {
        setState(() {
          _products = prods;
          _loadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _loadingProducts = false;
        _loadCategoryError = '${_loadCategoryError ?? ''} | Products: $e';
      });
      }
    }
  }

  // Which category IDs are currently active for filtering
  Set<String> get _activeCategoryIds {
    if (_selectedParent == null) return {}; // empty = show all

    // If a subcategory is selected, filter by that only
    if (_selectedChild != null) return {_selectedChild!.id};

    // If parent selected with no child, show parent + all its children
    final ids = {_selectedParent!.id};
    for (final child in _selectedParent!.children) {
      ids.add(child.id);
    }
    return ids;
  }

  List<Product> get _filteredProducts {
    var list = _products;

    final ids = _activeCategoryIds;
    if (ids.isNotEmpty) {
      list = list.where((p) => p.categoryId != null && ids.contains(p.categoryId)).toList();
    }

    if (_productSearch.isNotEmpty) {
      final q = _productSearch.toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  void _selectParent(ProductCategory? cat) {
    setState(() {
      _selectedParent = cat;
      _selectedChild = null; // reset child when parent changes
    });
  }

  void _selectChild(ProductCategory? cat) {
    setState(() => _selectedChild = cat);
  }

  void _addProduct(Product product, {String? variant, double? variantPrice}) {
    final price = variantPrice ?? product.price;
    final existingIdx = _items.indexWhere((item) =>
        item.productId == product.id && item.variant == (variant ?? ''));
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
          taxAmount: 0,
          variant: variant,
        ));
      }
    });
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  void _adjustQuantity(int index, int delta) {
    setState(() {
      _items[index].quantity += delta;
      if (_items[index].quantity <= 0) _items.removeAt(index);
    });
  }

  void _editComment(int index) {
    final ctrl = TextEditingController(text: _items[index].comment);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_items[index].name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Kitchen note / special request',
            hintText: 'e.g. No onions, extra spicy…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() => _items[index].comment = ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  double get _subtotal =>
      _items.fold(0, (sum, i) => sum + i.price * i.quantity);
  double _tax(double rate) => _subtotal * (rate / 100);
  double _total(double rate) => _subtotal + _tax(rate);

  Future<void> _saveOrder() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one item')));
      return;
    }
    final auth = context.read<AuthProvider>();
    final orders = context.read<OrdersProvider>();
    final vendor = auth.vendor;
    if (vendor == null) return;

    setState(() => _isSaving = true);
    final taxRate = vendor.settings.taxRate;

    final orderData = {
      'vendorId': vendor.id,
      'tableNumber': _tableController.text.trim(),
      'items': _items.map((i) => i.toJson()).toList(),
      'subtotal': _subtotal,
      'tax': _tax(taxRate),
      'total': _total(taxRate),
      'payment': {
        'method': 'cash',
        'status': 'pending',
        'paidAmount': 0,
        'changeDue': 0
      },
      'customer': {},
      'status': 'pending',
    };

    bool success;
    if (widget.existingOrder != null) {
      success = await orders.updateOrder(
//          auth.apiService, vendor.id, widget.existingOrder!.id, orderData);
          auth.apiService, widget.existingOrder!.id, orderData);
    } else {
      final created = await orders.createOrder(auth.apiService, vendor.id, orderData);
      success = created != null;
    }

    setState(() => _isSaving = false);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(orders.error ?? 'Failed to save order')));
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
    final tableText = _tableController.text;

    return Scaffold(
      appBar: AppBar(
        title: Text(tableText.isEmpty
            ? (isEditing ? 'Edit Order — Takeaway' : 'New Order — Takeaway')
            : (isEditing
                ? 'Edit Order — Table $tableText'
                : 'New Order — Table $tableText')),
        actions: [
          // Inline table number editor
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: SizedBox(
              width: 110,
              child: TextField(
                controller: _tableController,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Table',
                  hintText: 'Takeaway',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  suffixIcon: _tableController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () =>
                              setState(() => _tableController.clear()),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _saveOrder,
                icon: const Icon(Icons.check, size: 18),
                label: Text(isEditing ? 'Update' : 'Place Order'),
              ),
            ),
        ],
      ),
      body: Row(
        children: [
          // ── LEFT: search + category nav + product grid ────────────
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search products…',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() {
                      _productSearch = v;
                      // Clear category filter when searching
                      if (v.isNotEmpty) {
                        _selectedParent = null;
                        _selectedChild = null;
                      }
                    }),
                  ),
                ),

                if (_loadCategoryError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      _loadCategoryError!,
                      style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                    ),
                  ),

                if (_categories.isNotEmpty) ...[
                  // ── Parent category chips ──────────────────────
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _categories.length + 1, // +1 for All
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, index) {
                        final isAll = index == 0;
                        final cat = isAll ? null : _categories[index - 1];
                        final isSelected = isAll
                            ? _selectedParent == null
                            : _selectedParent?.id == cat!.id;
                        return ChoiceChip(
                          label: Text(isAll ? 'All' : cat!.name,
                              style: const TextStyle(fontSize: 13)),
                          selected: isSelected,
                          showCheckmark: false,
                          onSelected: (_) => _selectParent(isAll ? null : cat),
                        );
                      },
                    ),
                  ),

                  // ── Subcategory chips (shown when parent selected and has children)
                  if (_selectedParent != null &&
                      _selectedParent!.hasChildren) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _selectedParent!.children.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (ctx, index) {
                          final isAll = index == 0;
                          final child = isAll
                              ? null
                              : _selectedParent!.children[index - 1];
                          final isSelected = isAll
                              ? _selectedChild == null
                              : _selectedChild?.id == child!.id;
                          return ChoiceChip(
                            label: Text(isAll ? 'All ${_selectedParent!.name}' : child!.name,
                                style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            onSelected: (_) =>
                                _selectChild(isAll ? null : child),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                ],

                // Product count label
                if (!_loadingProducts)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '${_filteredProducts.length} product${_filteredProducts.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),

                const SizedBox(height: 4),

                // Product grid
                Expanded(
                  child: _loadingProducts
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredProducts.isEmpty
                          ? Center(
                              child: Text('No products found',
                                  style: TextStyle(
                                      color:
                                          theme.colorScheme.onSurfaceVariant)),
                            )
                          : GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 160,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.4,
                              ),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (ctx, i) {
                                final product = _filteredProducts[i];
                                return _ProductTile(
                                  product: product,
                                  fmt: fmt,
                                  onTap: () => product.variants.isNotEmpty
                                      ? _showVariantPicker(
                                          context, product, fmt)
                                      : _addProduct(product),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          VerticalDivider(
              width: 1, color: theme.colorScheme.outlineVariant),

          // ── RIGHT: order items + totals ───────────────────────────
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Text('Order',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      if (_items.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${_items.length}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      theme.colorScheme.onPrimaryContainer)),
                        ),
                      const Spacer(),
                      if (_items.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => setState(() => _items.clear()),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.error),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_cart_outlined,
                                  size: 48,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withOpacity(0.3)),
                              const SizedBox(height: 8),
                              Text('Tap a product to add',
                                  style: TextStyle(
                                      color: theme
                                          .colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) => _OrderItemCard(
                            item: _items[i],
                            fmt: fmt,
                            onIncrement: () => _adjustQuantity(i, 1),
                            onDecrement: () => _adjustQuantity(i, -1),
                            onRemove: () => _removeItem(i),
                            onEditComment: () => _editComment(i),
                          ),
                        ),
                ),
                _OrderTotalsPanel(
                  subtotal: _subtotal,
                  tax: _tax(taxRate),
                  total: _total(taxRate),
                  taxRate: taxRate,
                  fmt: fmt,
                  isSaving: _isSaving,
                  isEditing: isEditing,
                  onSave: _saveOrder,
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
        padding: const EdgeInsets.all(20),
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
            Text('Choose an option',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            // Base option first
            ListTile(
              title: Text('${product.name} (standard)'),
              trailing: Text(fmt.format(product.price),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _addProduct(product);
              },
            ),
            // Variants with price adjustment
            ...product.variants.map((v) {
              final variantPrice = product.price + v.priceAdjustment;
              return ListTile(
                title: Text(v.name),
                subtitle: v.priceAdjustment != 0
                    ? Text(
                        v.priceAdjustment > 0
                            ? '+${fmt.format(v.priceAdjustment)}'
                            : fmt.format(v.priceAdjustment),
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant))
                    : null,
                trailing: Text(fmt.format(variantPrice),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _addProduct(product,
                      variant: v.name, variantPrice: variantPrice);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Product tile ───────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final Product product;
  final NumberFormat fmt;
  final VoidCallback onTap;
  const _ProductTile(
      {required this.product, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (product.shortDesc != null &&
                  product.shortDesc!.isNotEmpty)
                Text(product.shortDesc!,
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fmt.format(product.price),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          fontSize: 13)),
                  Icon(Icons.add_circle,
                      size: 20, color: theme.colorScheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Order item card ────────────────────────────────────────────────────────────

class _OrderItemCard extends StatelessWidget {
  final OrderItem item;
  final NumberFormat fmt;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onEditComment;

  const _OrderItemCard({
    required this.item,
    required this.fmt,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onEditComment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + remove
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      if (item.variant != null && item.variant!.isNotEmpty)
                        Text(item.variant!,
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Qty + price
            Row(
              children: [
                _QtyButton(icon: Icons.remove, onTap: onDecrement),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('${item.quantity}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                _QtyButton(icon: Icons.add, onTap: onIncrement),
                const Spacer(),
                Text(fmt.format(item.price * item.quantity),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            // Comment row
            InkWell(
              onTap: onEditComment,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.comment_outlined,
                        size: 14,
                        color: item.comment.isNotEmpty
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.4)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.comment.isNotEmpty
                            ? item.comment
                            : 'Add note…',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: item.comment.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: item.comment.isNotEmpty
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.4),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.edit_outlined,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.3)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Icon(icon, size: 16, color: theme.colorScheme.primary),
      ),
    );
  }
}

// ── Totals panel ───────────────────────────────────────────────────────────────

class _OrderTotalsPanel extends StatelessWidget {
  final double subtotal, tax, total, taxRate;
  final NumberFormat fmt;
  final bool isSaving, isEditing;
  final VoidCallback onSave;

  const _OrderTotalsPanel({
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.taxRate,
    required this.fmt,
    required this.isSaving,
    required this.isEditing,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Column(
        children: [
          _TRow(label: 'Subtotal', value: fmt.format(subtotal)),
          const SizedBox(height: 4),
          _TRow(
              label: 'Tax (${taxRate.toStringAsFixed(0)}%)',
              value: fmt.format(tax)),
          const Divider(height: 14),
          _TRow(label: 'Total', value: fmt.format(total), bold: true),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSaving ? null : onSave,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isEditing ? 'Update order' : 'Place order',
                      style: const TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _TRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        fontSize: bold ? 15 : 13);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}
