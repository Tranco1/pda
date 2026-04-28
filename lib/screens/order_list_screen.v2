// lib/screens/order_list_screen.dart
// Shows all orders for a given table. 
// Read-only view for completed/cancelled orders, edit option for active ones.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../models/models.dart';
import 'order_entry_screen.dart';

class OrderListScreen extends StatelessWidget {
  final String tableNumber;
  final String tableLabel;
  final String? singleOrderId; // if set, only show this order

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

    if (singleOrderId != null) {
      tableOrders =
          tableOrders.where((o) => o.id == singleOrderId).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tableLabel),
        actions: [
          // Add new order to this table
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
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'No active orders',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
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
                        auth.apiService, order.id, newStatus);
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                orders.error ?? 'Failed to update status')),
                      );
                    }
                  },
                );
              },
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final NumberFormat fmt;
  final VoidCallback? onEdit;
  final Future<void> Function(String status) onUpdateStatus;

  const _OrderCard({
    required this.order,
    required this.fmt,
    this.onEdit,
    required this.onUpdateStatus,
  });

  Color _statusColor(BuildContext context, OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return Colors.green.shade700;
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: order.isEditable
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
                  'Order ${order.orderNumber}',
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
            const SizedBox(height: 12),

            // Items
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        '${item.quantity}×',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(item.name,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Text(
                        fmt.format(item.subtotal),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),

            const Divider(height: 20),

            // Totals
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

            // Actions (only for editable orders)
            if (order.isEditable) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (onEdit != null)
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                  if (order.status == OrderStatus.pending ||
                      order.status == OrderStatus.confirmed)
                    FilledButton.icon(
                      onPressed: () => onUpdateStatus('completed'),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Complete'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                    ),
                  if (order.status != OrderStatus.cancelled)
                    OutlinedButton.icon(
                      onPressed: () => onUpdateStatus('cancelled'),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
