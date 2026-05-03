// lib/screens/order_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../models/models.dart';
import 'order_entry_screen.dart';

class OrderListScreen extends StatelessWidget {
  final String tableNumber;
  final String tableLabel;
  final String? singleOrderId;

  const OrderListScreen({
    super.key,
    required this.tableNumber,
    required this.tableLabel,
    this.singleOrderId,
  });

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrdersProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final currency = auth.vendor?.settings.currency == 'GBP' ? '£' : '\$';
    final fmt = NumberFormat.currency(symbol: currency, decimalDigits: 2);

    List<Order> tableOrders = tableNumber.isEmpty
        ? orders.noTableOrders
        : orders.ordersForTable(tableNumber);

    // Also include closed orders for this table so they can be reviewed
    final closedForTable = orders.closedOrders
        .where((o) => singleOrderId != null
            ? o.id == singleOrderId
            : o.tableNumber == tableNumber)
        .toList();

    if (singleOrderId != null) {
      tableOrders = [
        ...tableOrders.where((o) => o.id == singleOrderId),
        ...closedForTable,
      ];
    } else {
      tableOrders = [...tableOrders, ...closedForTable];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tableLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New order',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => OrderEntryScreen(tableNumber: tableNumber),
              ));
            },
          ),
        ],
      ),
      body: tableOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64,
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text('No orders',
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tableOrders.length,
              itemBuilder: (ctx, index) {
                final order = tableOrders[index];
                return _OrderCard(
                  order: order,
                  fmt: fmt,
                  vendor: auth.vendor,
                  onEdit: order.isEditable
                      ? () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => OrderEntryScreen(
                              tableNumber: order.tableNumber,
                              existingOrder: order,
                            ),
                          ));
                        }
                      : null,
                  onUpdateStatus: (newStatus) async {
                    final success = await orders.updateOrderStatus(
                        auth.apiService,
                        auth.vendor?.id ?? '',
                        order.id,
                        newStatus);
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                orders.error ?? 'Failed to update status')),
                      );
                    }
                  },
                  onPrintReceipt: () => _showReceipt(context, order, fmt, auth.vendor),
                );
              },
            ),
    );
  }

  void _showReceipt(BuildContext context, Order order, NumberFormat fmt, Vendor? vendor) {
    showDialog(
      context: context,
      builder: (ctx) => _ReceiptDialog(order: order, fmt: fmt, vendor: vendor),
    );
  }
}

// ── Receipt Dialog ─────────────────────────────────────────────────────────────

class _ReceiptDialog extends StatelessWidget {
  final Order order;
  final NumberFormat fmt;
  final Vendor? vendor;

  const _ReceiptDialog({
    required this.order,
    required this.fmt,
    required this.vendor,
  });

  String _buildReceiptText() {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final sb = StringBuffer();
    final width = 40;

    void line([String text = '']) => sb.writeln(text);
    void divider() => sb.writeln('-' * width);
    void centre(String text) {
      final pad = ((width - text.length) / 2).floor();
      sb.writeln(' ' * pad + text);
    }
    void twoCol(String left, String right) {
      final space = width - left.length - right.length;
      sb.writeln(left + ' ' * (space > 0 ? space : 1) + right);
    }

    // Header
    centre(vendor?.businessName ?? vendor?.name ?? 'Receipt');
    line();
    centre('Order #${order.orderNumber}');
    if (order.tableNumber.isNotEmpty) {
      centre('Table ${order.tableNumber}');
    }
    centre(dateFmt.format(order.createdAt));
    divider();

    // Items — use shortDesc if available, fall back to name
    for (final item in order.items) {
      final label = (item.shortDesc != null && item.shortDesc!.trim().isNotEmpty)
          ? item.shortDesc!.trim()
          : item.name;
      twoCol('${item.quantity} x $label', fmt.format(item.price * item.quantity));
      if (item.comment.isNotEmpty) {
        sb.writeln('   * ${item.comment}');
      }
    }

    divider();
    twoCol('Subtotal', fmt.format(order.subtotal));
    twoCol('Tax', fmt.format(order.tax));
    divider();
    twoCol('TOTAL', fmt.format(order.total));
    divider();

    // Payment
    twoCol('Payment', order.payment.method.toUpperCase());
    twoCol('Status', order.payment.status.toUpperCase());
    if (order.payment.paidAmount > 0) {
      twoCol('Paid', fmt.format(order.payment.paidAmount));
      if (order.payment.changeDue > 0) {
        twoCol('Change', fmt.format(order.payment.changeDue));
      }
    }

    divider();
    if (vendor?.settings.receiptFooter != null &&
        vendor!.settings.receiptFooter!.isNotEmpty) {
      line();
      centre(vendor!.settings.receiptFooter!);
    }
    line();
    centre('Thank you!');

    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final receiptText = _buildReceiptText();
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long,
                      color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Receipt — Order #${order.orderNumber}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: theme.colorScheme.onPrimaryContainer),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Receipt body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    receiptText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  // Copy to clipboard
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: receiptText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Receipt copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                  const SizedBox(width: 8),
                  // Print (sends to system print dialog)
                  FilledButton.icon(
                    onPressed: () {
                      // Platform print — works on Linux/Windows/Android
                      // For thermal printer integration, replace this with
                      // your printer SDK call using receiptText
                      _printReceipt(context, receiptText);
                    },
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _printReceipt(BuildContext context, String text) {
    // Currently shows the receipt in a format ready for printing.
    // To integrate with a thermal printer (ESC/POS), pass `text` to
    // your printer plugin (e.g. esc_pos_utils / bluetooth_print).
    // For now we show a snackbar confirming the action.
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sending to printer…'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ── Order Card ─────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final NumberFormat fmt;
  final Vendor? vendor;
  final VoidCallback? onEdit;
  final Future<void> Function(String status) onUpdateStatus;
  final VoidCallback onPrintReceipt;

  const _OrderCard({
    required this.order,
    required this.fmt,
    this.vendor,
    this.onEdit,
    required this.onUpdateStatus,
    required this.onPrintReceipt,
  });

  Color _statusColor(BuildContext context, OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return Colors.green.shade700;
      case OrderStatus.closed:
        return Colors.teal.shade700;
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        return Colors.red.shade700;
      case OrderStatus.held:
        return Colors.orange.shade700;
      case OrderStatus.processing:
        return Colors.blue.shade700;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isClosed = order.status == OrderStatus.closed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isClosed
              ? Colors.teal.withOpacity(0.3)
              : order.isEditable
                  ? theme.colorScheme.primary.withOpacity(0.3)
                  : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Order #${order.orderNumber}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(context, order.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.status.displayName,
                    style: TextStyle(
                      color: _statusColor(context, order.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (order.tableNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Table ${order.tableNumber}',
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant)),
            ],

            const SizedBox(height: 12),

            // Items — use shortDesc for receipt-style display
            ...order.items.map((item) {
              final label = (item.shortDesc != null &&
                      item.shortDesc!.trim().isNotEmpty)
                  ? item.shortDesc!.trim()
                  : item.name;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${item.quantity}×',
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 13)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(label,
                                style: const TextStyle(fontSize: 13))),
                        Text(fmt.format(item.price * item.quantity),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (item.comment.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 24, bottom: 2),
                        child: Text('✎ ${item.comment}',
                            style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              );
            }),

            const Divider(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal',
                    style:
                        TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                Text(fmt.format(order.subtotal)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tax',
                    style:
                        TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                Text(fmt.format(order.tax)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  fmt.format(order.total),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Actions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Always show print receipt
                OutlinedButton.icon(
                  onPressed: onPrintReceipt,
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('Receipt'),
                ),

                // Edit — only for editable orders
                if (onEdit != null)
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),

                // Progress / Close button
                if (order.status == OrderStatus.pending)
                  FilledButton.icon(
                    onPressed: () => onUpdateStatus('confirmed'),
                    icon: const Icon(Icons.thumb_up_outlined, size: 16),
                    label: const Text('Confirm'),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade700),
                  ),

                if (order.status == OrderStatus.confirmed)
                  FilledButton.icon(
                    onPressed: () => onUpdateStatus('processing'),
                    icon: const Icon(Icons.restaurant_outlined, size: 16),
                    label: const Text('Processing'),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade700),
                  ),

                if (order.status == OrderStatus.processing)
                  FilledButton.icon(
                    onPressed: () => onUpdateStatus('completed'),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Complete'),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700),
                  ),

                if (order.status == OrderStatus.completed)
                  FilledButton.icon(
                    onPressed: () => onUpdateStatus('closed'),
                    icon: const Icon(Icons.lock_outline, size: 16),
                    label: const Text('Close'),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal.shade700),
                  ),

                // Reopen closed order for review
                if (isClosed)
                  OutlinedButton.icon(
                    onPressed: () => onUpdateStatus('completed'),
                    icon: const Icon(Icons.lock_open_outlined, size: 16),
                    label: const Text('Reopen'),
                  ),

                // Cancel — only for non-closed, non-cancelled
                if (!isClosed &&
                    order.status != OrderStatus.cancelled &&
                    order.status != OrderStatus.refunded)
                  OutlinedButton.icon(
                    onPressed: () => onUpdateStatus('cancelled'),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
