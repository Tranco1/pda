// lib/screens/dashboard_screen.dart
// The main dashboard: table grid + no-table active orders section.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../models/models.dart';
import 'login_screen.dart';
import 'order_list_screen.dart';
import 'order_entry_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Delay slightly to ensure auth provider has finished vendor fetch
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrders());
  }

  Future<void> _loadOrders() async {
    final auth = context.read<AuthProvider>();
    final orders = context.read<OrdersProvider>();

    // If vendor not loaded yet, wait briefly and retry
    if (auth.vendor == null) {
      debugPrint('Dashboard: vendor not ready, retrying in 500ms');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }

    final vendorId = auth.vendor?.id;
    debugPrint('Dashboard: loading orders for vendorId=$vendorId, numberOfTables=${auth.vendor?.numberOfTables}');
    if (vendorId == null || vendorId.isEmpty) {
      debugPrint('Dashboard: no vendorId available');
      return;
    }
    await orders.fetchOrders(auth.apiService, vendorId);
  }

  void _handleTableTap(
      BuildContext context, int tableNumber, bool hasActiveOrders) {
    final tableStr = tableNumber.toString();
    if (hasActiveOrders) {
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (_) => OrderListScreen(
              tableNumber: tableStr,
              tableLabel: 'Table $tableNumber',
            ),
          ))
          .then((_) => _loadOrders());
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (_) => OrderEntryScreen(tableNumber: tableStr),
          ))
          .then((_) => _loadOrders());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final orders = context.watch<OrdersProvider>();
    final vendor = auth.vendor;
    final numTables = vendor?.numberOfTables ?? 0;
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      symbol: vendor?.settings.currency == 'GBP' ? '£' : '\$',
      decimalDigits: 2,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vendor?.businessName ?? vendor?.name ?? 'Dashboard',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (vendor != null)
              Text(
                '${numTables} tables',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadOrders,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person_outline),
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Text(auth.user?.name ?? ''),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Sign out'),
                  ],
                ),
              ),
            ],
            onSelected: (val) async {
              if (val == 'logout') {
                await auth.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              }
            },
          ),
        ],
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: orders.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: CustomScrollView(
                slivers: [
                  // ── Error banner ──────────────────────────────
                  if (orders.error != null)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          orders.error!,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ),

                  // ── Debug info (remove once working) ─────────
//                  SliverToBoxAdapter(
//                    child: Padding(
//                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
//                      child: Text(
//                        'DEBUG: vendor=${vendor?.name}, tables=$numTables, orders=${orders.orders.length}, error=${orders.error}',
//                        style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
//                      ),
//                    ),
//                  ),

                  // ── Table grid ────────────────────────────────
                  if (numTables > 0) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Tables',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, index) {
                            final tableNum = index + 1;
                            final tableStr = tableNum.toString();
                            final hasOrders =
                                orders.tableHasActiveOrders(tableStr);
                            final total = orders.tableTotalValue(tableStr);

                            return _TableButton(
                              tableNumber: tableNum,
                              hasActiveOrders: hasOrders,
                              totalValue: hasOrders ? total : null,
                              currencyFormat: currencyFormat,
                              onTap: () =>
                                  _handleTableTap(context, tableNum, hasOrders),
                            );
                          },
                          childCount: numTables,
                        ),
                      ),
                    ),
                  ],

                  // ── No-table orders ───────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Online / Takeaway',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (orders.noTableOrders.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${orders.noTableOrders.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context)
                                  .push(MaterialPageRoute(
                                    builder: (_) =>
                                        const OrderEntryScreen(tableNumber: ''),
                                  ))
                                  .then((_) => _loadOrders());
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (orders.noTableOrders.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'No active online or takeaway orders',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, index) {
                            final order = orders.noTableOrders[index];
                            return _NoTableOrderCard(
                              order: order,
                              currencyFormat: currencyFormat,
                              onTap: () {
                                Navigator.of(context)
                                    .push(MaterialPageRoute(
                                      builder: (_) => OrderListScreen(
                                        tableNumber: '',
                                        tableLabel: 'Online / Takeaway',
                                        singleOrderId: order.id,
                                      ),
                                    ))
                                    .then((_) => _loadOrders());
                              },
                            );
                          },
                          childCount: orders.noTableOrders.length,
                        ),
                      ),
                    ),

                  // ── Completed Orders ─────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Completed Orders',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (orders.closedOrders.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${orders.closedOrders.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  if (orders.closedOrders.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'No closed orders today',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, index) {
                            final order = orders.closedOrders[index];
                            return _NoTableOrderCard(
                              order: order,
                              currencyFormat: currencyFormat,
                              onTap: () {
                                Navigator.of(context)
                                    .push(MaterialPageRoute(
                                      builder: (_) => OrderListScreen(
                                        tableNumber: order.tableNumber,
                                        tableLabel: order.tableNumber.isEmpty
                                            ? 'Online / Takeaway'
                                            : 'Table ${order.tableNumber}',
                                        singleOrderId: order.id,
                                      ),
                                    ))
                                    .then((_) => _loadOrders());
                              },
                            );
                          },
                          childCount: orders.closedOrders.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
    );
  }
}

// ─── Table Button Widget ───────────────────────────────────────────────────────

class _TableButton extends StatelessWidget {
  final int tableNumber;
  final bool hasActiveOrders;
  final double? totalValue;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  const _TableButton({
    required this.tableNumber,
    required this.hasActiveOrders,
    this.totalValue,
    required this.currencyFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = const Color(0xFF2E7D32); // green-800
    final activeLight = const Color(0xFFE8F5E9); // green-50
    final emptyColor = theme.colorScheme.surfaceContainerHighest;
    final emptyOnColor = theme.colorScheme.onSurfaceVariant;

    return Material(
      color: hasActiveOrders ? activeLight : emptyColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasActiveOrders
                  ? activeColor.withOpacity(0.4)
                  : theme.colorScheme.outlineVariant,
              width: hasActiveOrders ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.table_restaurant_rounded,
                size: 28,
                color: hasActiveOrders ? activeColor : emptyOnColor,
              ),
              const SizedBox(height: 6),
              Text(
                'Table $tableNumber',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: hasActiveOrders ? activeColor : emptyOnColor,
                ),
              ),
              const SizedBox(height: 4),
              if (hasActiveOrders && totalValue != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    currencyFormat.format(totalValue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Text(
                  'Empty',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── No-table order card ───────────────────────────────────────────────────────

class _NoTableOrderCard extends StatelessWidget {
  final Order order;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  const _NoTableOrderCard({
    required this.order,
    required this.currencyFormat,
    required this.onTap,
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
      child: ListTile(
        leading: const Icon(Icons.shopping_bag_outlined),
        title: Text(
          'Order ${order.orderNumber}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${order.items.length} item${order.items.length == 1 ? '' : 's'} · ${order.status.displayName}',
        ),
        trailing: Text(
          currencyFormat.format(order.total),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
