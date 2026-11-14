import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../services/database_service.dart';
import '../services/order_contract.dart';
import '../theme/app_theme.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Placed',
    'Accepted',
    'Packed',
    'In Transit',
    'Delivered',
    'Rejected',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final db = ref.watch(databaseServiceProvider);
    final authUser = ref.watch(authUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Online Orders Inbox',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          ordersAsync.when(
            data: (orders) {
              final placedCount = orders.where((o) => o.isPlaced).length;
              if (placedCount == 0) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_active_rounded,
                        color: AppColors.error, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$placedCount Pending',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(filter),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : colors.textSecondary,
                      ),
                      backgroundColor: colors.surfaceCard,
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      onSelected: (_) => setState(() => _selectedFilter = filter),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),

            // Orders list
            Expanded(
              child: ordersAsync.when(
                data: (allOrders) {
                  final filteredOrders = allOrders.where((order) {
                    if (_selectedFilter == 'All') return true;
                    if (_selectedFilter == 'Placed') return order.isPlaced;
                    if (_selectedFilter == 'Accepted') return order.isAccepted;
                    if (_selectedFilter == 'Packed') return order.isPacked;
                    if (_selectedFilter == 'In Transit') {
                      return order.isRiderAssigned || order.isPicked;
                    }
                    if (_selectedFilter == 'Delivered') return order.isDelivered;
                    if (_selectedFilter == 'Rejected') {
                      return order.isRejected || order.isCancelled;
                    }
                    return true;
                  }).toList();

                  if (filteredOrders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 54, color: colors.textHint),
                          const SizedBox(height: 12),
                          Text(
                            _selectedFilter == 'All'
                                ? 'No online orders received yet'
                                : 'No orders in "$_selectedFilter" state',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Incoming customer orders will appear here in real time.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return _buildOrderCard(
                        context,
                        order,
                        colors,
                        db,
                        authUser?.uid ?? '',
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Error loading orders: $e',
                    style: GoogleFonts.inter(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    KlinixyOrder order,
    AppColors colors,
    DatabaseService? db,
    String currentUid,
  ) {
    final timeStr = DateFormat('dd MMM, hh:mm a').format(order.createdAt);
    final statusColor = _statusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: order.isPlaced
              ? AppColors.primary.withValues(alpha: 0.5)
              : colors.surfaceLight,
          width: order.isPlaced ? 1.5 : 1,
        ),
        boxShadow: order.isPlaced
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                  style: GoogleFonts.robotoMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Customer Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_pin_circle_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      order.customerName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (order.customerPhone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${order.customerPhone})',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (order.deliveryAddress.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    order.deliveryAddress,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Prescription indicator if available
          if (order.prescriptionUrl != null &&
              order.prescriptionUrl!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                        size: 16, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Prescription Attached',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Items Table
          Container(
            color: colors.surfaceLight.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          item.medicineName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'x${item.quantity}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '₹${item.totalPrice.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Payment & Total
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.paymentMethod.toUpperCase()} (${order.paymentStatus})',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (order.deliveryFee > 0)
                      Text(
                        'Incl. ₹${order.deliveryFee.toStringAsFixed(0)} delivery fee',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: colors.textHint,
                        ),
                      ),
                  ],
                ),
                Text(
                  '₹${order.total.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Rejection reason callout if rejected
          if (order.isRejected &&
              order.rejectionReason != null &&
              order.rejectionReason!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rejection Reason: ${order.rejectionReason}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action Buttons
          if (order.isPlaced) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(
                        context,
                        order.id,
                        db,
                        currentUid,
                      ),
                      icon: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.error),
                      label: Text(
                        'Reject',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleAcceptOrder(
                        context,
                        order,
                        db,
                        currentUid,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        'Accept Order',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (order.isAccepted) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: () => _handleMarkPacked(
                  context,
                  order.id,
                  db,
                  currentUid,
                ),
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: Text(
                  'Mark Order as Packed',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else if (order.isPacked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.accent.withValues(alpha: 0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.two_wheeler_rounded,
                      size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Packed • Awaiting Rider Pickup',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (order.isRiderAssigned || order.isPicked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.cyan.withValues(alpha: 0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delivery_dining_rounded,
                      size: 16, color: Colors.cyan),
                  const SizedBox(width: 8),
                  Text(
                    'Handed Over to Rider • Out for Delivery',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.cyan,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (order.isDelivered) ...[
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.success.withValues(alpha: 0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(
                    'Order Completed & Delivered',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'placed':
        return AppColors.warning;
      case 'accepted':
        return AppColors.primary;
      case 'packed':
        return AppColors.accent;
      case 'rider_assigned':
      case 'picked':
        return Colors.cyan;
      case 'delivered':
        return AppColors.success;
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleAcceptOrder(
    BuildContext context,
    KlinixyOrder order,
    DatabaseService? db,
    String uid,
  ) async {
    if (db == null) return;
    try {
      await db.acceptOrder(order: order, byUid: uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted! Stock decremented atomically.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot Accept Order'),
            content: Text('$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleMarkPacked(
    BuildContext context,
    String orderId,
    DatabaseService? db,
    String uid,
  ) async {
    if (db == null) return;
    try {
      await db.markOrderPacked(orderId: orderId, byUid: uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as packed! Ready for rider pickup.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showRejectDialog(
    BuildContext context,
    String orderId,
    DatabaseService? db,
    String uid,
  ) {
    final reasonCtrl = TextEditingController();
    String selectedReason = 'Out of stock';
    final options = [
      'Out of stock',
      'Pharmacy closing soon',
      'Invalid prescription',
      'Delivery location out of range',
      'Other reason',
    ];

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            'Reject Order',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please select a mandatory reason for rejecting this customer order:',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                items: options
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setDlgState(() => selectedReason = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes / Explanation *',
                  hintText: 'e.g. Paracetamol batch exhausted',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final reason = reasonCtrl.text.trim().isNotEmpty
                    ? '$selectedReason: ${reasonCtrl.text.trim()}'
                    : selectedReason;

                Navigator.pop(dlgCtx);
                if (db != null) {
                  try {
                    await db.rejectOrder(
                      orderId: orderId,
                      reason: reason,
                      byUid: uid,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order rejected with reason logged.'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to reject order: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Reject Order'),
            ),
          ],
        ),
      ),
    );
  }
}
