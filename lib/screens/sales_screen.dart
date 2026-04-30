import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../models/sale.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String _selectedRange = 'Today';
  final _ranges = ['Today', 'This Week', 'This Month', 'All Time'];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final salesAsync = ref.watch(salesStreamProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Analytics', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: colors.surfaceLight, borderRadius: BorderRadius.circular(10)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRange,
                        dropdownColor: colors.surface,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: colors.textSecondary),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        items: _ranges.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (v) => setState(() => _selectedRange = v!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            salesAsync.when(
              data: (sales) {
                final filteredSales = _filterSalesByRange(sales, _selectedRange);
                final revenue = filteredSales.fold<double>(0, (sum, s) => sum + s.totalPrice);
                final topSelling = _getTopSelling(filteredSales);

                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.05)]),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text("$_selectedRange's Revenue", style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary)),
                            const SizedBox(height: 4),
                            Text('₹${NumberFormat('#,##0').format(revenue)}', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ]),
                          const Spacer(),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                            Text('Orders', style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary)),
                            const SizedBox(height: 4),
                            Text('${filteredSales.length}', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      if (topSelling.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Top Selling Items', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: topSelling.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (_, i) {
                              final item = topSelling[i];
                              return Container(
                                width: 140,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: colors.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.surfaceLight)),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                                  Text(item.key, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const Spacer(),
                                  Text('${item.value} units sold', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                                ]),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('Transactions ($_selectedRange)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: filteredSales.isEmpty
                            ? Center(child: Text('No transactions found', style: GoogleFonts.inter(color: colors.textSecondary)))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filteredSales.length,
                                itemBuilder: (_, i) {
                                  final sale = filteredSales[i];
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(color: colors.surfaceCard, borderRadius: BorderRadius.circular(14)),
                                    child: Row(children: [
                                      Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.success.withValues(alpha: 0.12)), child: const Icon(Icons.receipt_long_rounded, color: AppColors.success, size: 22)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                        Text(sale.medicineName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 3),
                                        Text('${sale.customerName}  •  Qty: ${sale.quantity}', style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
                                      ])),
                                      Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                                        Text('₹${sale.totalPrice.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success)),
                                        const SizedBox(height: 3),
                                        Text(_formatTime(sale.date), style: GoogleFonts.inter(fontSize: 10, color: colors.textHint)),
                                      ]),
                                    ]),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Expanded(child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => Expanded(child: Center(child: Text('Error: $err'))),
            ),
          ],
        ),
      ),
    );
  }

  List<Sale> _filterSalesByRange(List<Sale> sales, String range) {
    final now = DateTime.now();
    return sales.where((s) {
      if (range == 'All Time') return true;
      if (range == 'Today') return s.date.year == now.year && s.date.month == now.month && s.date.day == now.day;
      if (range == 'This Week') return s.date.isAfter(now.subtract(const Duration(days: 7)));
      if (range == 'This Month') return s.date.year == now.year && s.date.month == now.month;
      return true;
    }).toList();
  }

  List<MapEntry<String, int>> _getTopSelling(List<Sale> sales) {
    final Map<String, int> counts = {};
    for (var sale in sales) { counts[sale.medicineName] = (counts[sale.medicineName] ?? 0) + sale.quantity; }
    final entries = counts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd MMM').format(dt);
  }
}
