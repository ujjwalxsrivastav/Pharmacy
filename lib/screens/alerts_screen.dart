import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final medicinesAsync = ref.watch(medicinesStreamProvider);
    final salesAsync = ref.watch(salesStreamProvider);

    return Scaffold(
      body: SafeArea(
        child: medicinesAsync.when(
          data: (medicines) {
            final sales = salesAsync.valueOrNull ?? [];

            // Calculate categories
            final lowStock = medicines.where((m) => m.isLowStock && !m.isExpired).toList();
            final expiringSoon = medicines.where((m) => m.isExpiringSoon).toList();
            final expired = medicines.where((m) => m.isExpired).toList();

            // Slow moving: medicines with 0 sales in the last 30 days
            final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
            final recentSalesMedIds = sales
                .where((s) => s.date.isAfter(thirtyDaysAgo))
                .expand((s) => s.items.map((i) => i.medicineId))
                .toSet();

            final slowMoving = medicines
                .where((m) => !recentSalesMedIds.contains(m.id) && m.stock > 0 && !m.isExpired)
                .toList();

            final allCount = lowStock.length + expiringSoon.length + expired.length + slowMoving.length;

            final categories = [
              {'id': 'All', 'label': 'All Alerts ($allCount)'},
              {'id': 'low', 'label': 'Low Stock (${lowStock.length})'},
              {'id': 'expSoon', 'label': 'Expiring Soon (${expiringSoon.length})'},
              {'id': 'expired', 'label': 'Expired (${expired.length})'},
              {'id': 'slow', 'label': 'Slow Moving (${slowMoving.length})'},
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alerts & Inventory Health',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Real-time stock warnings & expiration monitoring',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: categories.map((cat) {
                      final isSelected = _selectedCategory == cat['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat['label']!),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: colors.surfaceLight,
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : colors.textSecondary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                            ),
                          ),
                          onSelected: (_) => setState(() => _selectedCategory = cat['id']!),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Content
                Expanded(
                  child: _buildAlertsList(
                    context: context,
                    colors: colors,
                    lowStock: lowStock,
                    expiringSoon: expiringSoon,
                    expired: expired,
                    slowMoving: slowMoving,
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildAlertsList({
    required BuildContext context,
    required AppColors colors,
    required List<Medicine> lowStock,
    required List<Medicine> expiringSoon,
    required List<Medicine> expired,
    required List<Medicine> slowMoving,
  }) {
    final List<Widget> items = [];

    if (_selectedCategory == 'All' || _selectedCategory == 'low') {
      for (final m in lowStock) {
        items.add(_buildAlertCard(
          context: context,
          colors: colors,
          medicine: m,
          title: 'Low Stock: ${m.name}',
          subtitle: 'Only ${m.stock} left in stock (Min required: ${m.reorderLevel}) - Needs reorder',
          type: 'low',
          badgeColor: AppColors.warning,
          icon: Icons.inventory_2_outlined,
          actionLabel: 'Stock In',
          onAction: () => _showQuickStockInDialog(context, m),
        ));
      }
    }

    if (_selectedCategory == 'All' || _selectedCategory == 'expSoon') {
      for (final m in expiringSoon) {
        final days = m.expiryDate.difference(DateTime.now()).inDays;
        items.add(_buildAlertCard(
          context: context,
          colors: colors,
          medicine: m,
          title: 'Expiring Soon: ${m.name}',
          subtitle: 'Expires in $days days (${DateFormat('dd MMM yyyy').format(m.expiryDate)})',
          type: 'expSoon',
          badgeColor: AppColors.accent,
          icon: Icons.timer_outlined,
          actionLabel: 'Review',
          onAction: () => _showQuickStockInDialog(context, m),
        ));
      }
    }

    if (_selectedCategory == 'All' || _selectedCategory == 'expired') {
      for (final m in expired) {
        items.add(_buildAlertCard(
          context: context,
          colors: colors,
          medicine: m,
          title: 'EXPIRED: ${m.name}',
          subtitle: 'Expired on ${DateFormat('dd MMM yyyy').format(m.expiryDate)} - Remove from active inventory',
          type: 'expired',
          badgeColor: AppColors.error,
          icon: Icons.dangerous_outlined,
          actionLabel: 'Stock Out',
          onAction: () => _showQuickStockOutDialog(context, m),
        ));
      }
    }

    if (_selectedCategory == 'All' || _selectedCategory == 'slow') {
      for (final m in slowMoving) {
        items.add(_buildAlertCard(
          context: context,
          colors: colors,
          medicine: m,
          title: 'Slow Moving Stock: ${m.name}',
          subtitle: '0 sales in the last 30 days - Holding ${m.stock} units',
          type: 'slow',
          badgeColor: Colors.deepPurple,
          icon: Icons.trending_down_rounded,
          actionLabel: 'Stock In',
          onAction: () => _showQuickStockInDialog(context, m),
        ));
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 56, color: AppColors.success),
            const SizedBox(height: 12),
            Text(
              'All Clear!',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'No alerts at this time. All inventory is healthy!',
              style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => items[i],
    );
  }

  Widget _buildAlertCard({
    required BuildContext context,
    required AppColors colors,
    required Medicine medicine,
    required String title,
    required String subtitle,
    required String type,
    required Color badgeColor,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: badgeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: badgeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickStockInDialog(BuildContext context, Medicine med) {
    final qtyCtrl = TextEditingController(text: '10');
    final db = ref.read(databaseServiceProvider);
    if (db == null) return;

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Stock In: ${med.name}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Stock: ${med.stock} units', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [10, 25, 50, 100].map((num) {
                  return ActionChip(
                    label: Text('+$num'),
                    onPressed: () => qtyCtrl.text = num.toString(),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity to Add',
                  isDense: true,
                  border: OutlineInputBorder(),
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
              onPressed: () async {
                final delta = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (delta > 0) {
                  await db.adjustStock(med.id, delta);
                  if (dlgCtx.mounted) {
                    Navigator.pop(dlgCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added $delta units to ${med.name}'), backgroundColor: AppColors.success),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              child: const Text('Confirm Stock In'),
            ),
          ],
        );
      },
    );
  }

  void _showQuickStockOutDialog(BuildContext context, Medicine med) {
    final qtyCtrl = TextEditingController(text: '${med.stock}');
    final db = ref.read(databaseServiceProvider);
    if (db == null) return;

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Stock Out / Dispose: ${med.name}',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available to remove: ${med.stock} units',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity to Remove',
                  isDense: true,
                  border: OutlineInputBorder(),
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
              onPressed: () async {
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (qty <= 0) return;
                if (qty > med.stock) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cannot remove $qty. Current stock is only ${med.stock}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                await db.adjustStock(med.id, -qty);
                if (dlgCtx.mounted) {
                  Navigator.pop(dlgCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Removed $qty units of ${med.name} from inventory'),
                        backgroundColor: AppColors.warning),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: const Text('Confirm Removal'),
            ),
          ],
        );
      },
    );
  }
}
