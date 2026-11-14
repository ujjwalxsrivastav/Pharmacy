import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../models/sale.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';
import '../services/printer_service.dart';
import '../widgets/bill_receipt_dialog.dart';
import '../utils/csv_export.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  // Period filter: default 'Month' per Klinixy specification
  String _selectedRange = 'Month';
  final _ranges = ['Today', '7 Days', 'Month', 'Year', 'Custom'];
  DateTimeRange? _customRange;

  String _searchQuery = '';
  String _selectedBillType = 'All'; // 'All', 'pakka', 'kaccha'

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final salesAsync = ref.watch(salesStreamProvider);
    final medicinesAsync = ref.watch(medicinesStreamProvider);
    final profile = ref.watch(pharmacyProfileProvider).valueOrNull;
    final db = ref.watch(databaseServiceProvider);
    final authUser = ref.watch(authUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: salesAsync.when(
          data: (allSales) {
            final filteredSales =
                _filterSalesByRange(allSales, _selectedRange, _customRange);
            final medicines = medicinesAsync.valueOrNull ?? [];

            // Math calculations
            final totalRevenue =
                filteredSales.fold<double>(0, (sum, s) => sum + s.totalPrice);
            final pakkaSales = filteredSales.where((s) => s.isPakka).toList();
            final kacchaSales = filteredSales.where((s) => !s.isPakka).toList();
            final totalGst =
                pakkaSales.fold<double>(0, (sum, s) => sum + s.taxAmount);
            final totalOrders = filteredSales.length;
            final avgOrderValue =
                totalOrders > 0 ? (totalRevenue / totalOrders) : 0.0;

            // Hourly distribution for peak hours (full 24h spread: 12AM - 11PM)
            final hourlyCounts = List<int>.filled(24, 0);
            for (final sale in filteredSales) {
              final h = sale.date.hour;
              if (h >= 0 && h < 24) {
                hourlyCounts[h] += 1;
              }
            }
            int maxHourIdx = 0;
            int maxHourVal = 0;
            for (int i = 0; i < hourlyCounts.length; i++) {
              if (hourlyCounts[i] > maxHourVal) {
                maxHourVal = hourlyCounts[i];
                maxHourIdx = i;
              }
            }
            final peakHourLabel =
                maxHourVal > 0 ? _formatHourRange(maxHourIdx) : 'N/A';

            // Lower sections analytics
            final topSelling = _calculateTopSelling(filteredSales);
            final slowMoving = _calculateSlowMoving(medicines, filteredSales);
            final categoryRevenue =
                _calculateCategoryRevenue(filteredSales, medicines);

            // Transaction search & filter
            final displayTransactions = filteredSales.where((s) {
              final matchesQuery = _searchQuery.isEmpty ||
                  s.billNo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  s.customerName
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ||
                  s.medicineName
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
              final matchesType = _selectedBillType == 'All' ||
                  s.billType == _selectedBillType;
              return matchesQuery && matchesType;
            }).toList();

            return CustomScrollView(
              slivers: [
                // Header & Action Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with Back button and Green Export Pill Button
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back_rounded,
                                  color: colors.textPrimary),
                              tooltip: 'Back to Dashboard',
                              onPressed: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  ref
                                      .read(selectedTabProvider.notifier)
                                      .set(0);
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reports',
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Peak sales hours, top products & custom metrics',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Green Pill Export Button with Dropdown
                            _buildExportDropdown(
                              context: context,
                              colors: colors,
                              filteredSales: filteredSales,
                              profile: profile,
                              topSelling: topSelling,
                              slowMoving: slowMoving,
                              categoryRevenue: categoryRevenue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Period Pills: Today, 7 Days, Month (default), Year, Custom (calendar icon)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _ranges.map((r) {
                              final isSelected = _selectedRange == r;
                              String labelText = r;
                              if (r == 'Custom' && _customRange != null) {
                                labelText =
                                    '${DateFormat('d MMM').format(_customRange!.start)} - ${DateFormat('d MMM').format(_customRange!.end)}';
                              }

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  avatar: r == 'Custom'
                                      ? Icon(
                                          Icons.calendar_today_rounded,
                                          size: 14,
                                          color: isSelected
                                              ? Colors.white
                                              : colors.textSecondary,
                                        )
                                      : null,
                                  label: Text(labelText),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  backgroundColor: colors.surfaceLight,
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : colors.textSecondary,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                    ),
                                  ),
                                  onSelected: (_) async {
                                    if (r == 'Custom') {
                                      final picked =
                                          await showDateRangePicker(
                                        context: context,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now().add(
                                            const Duration(days: 365)),
                                        initialDateRange: _customRange ??
                                            DateTimeRange(
                                              start: DateTime.now().subtract(
                                                  const Duration(days: 7)),
                                              end: DateTime.now(),
                                            ),
                                        builder: (ctx, child) {
                                          return Theme(
                                            data: Theme.of(ctx).copyWith(
                                              colorScheme: Theme.of(ctx)
                                                  .colorScheme
                                                  .copyWith(
                                                    primary:
                                                        AppColors.primary,
                                                    onPrimary: Colors.white,
                                                  ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _customRange = picked;
                                          _selectedRange = 'Custom';
                                        });
                                      }
                                    } else {
                                      setState(() => _selectedRange = r);
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4 Stat Cards (as specified in §2: Total Revenue, Avg Order Value, GST Collected, Invoice Types)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 600;
                            final cardWidth = isWide
                                ? (constraints.maxWidth - 36) / 4
                                : (constraints.maxWidth - 12) / 2;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildKpiCard(
                                  context: context,
                                  width: cardWidth,
                                  title: 'Total Revenue',
                                  value:
                                      '₹${NumberFormat('#,##0').format(totalRevenue)}',
                                  subtitle: '$totalOrders orders total',
                                  icon: Icons.currency_rupee_rounded,
                                  iconColor: AppColors.primary,
                                  colors: colors,
                                ),
                                _buildKpiCard(
                                  context: context,
                                  width: cardWidth,
                                  title: 'Avg Order Value',
                                  value:
                                      '₹${NumberFormat('#,##0').format(avgOrderValue)}',
                                  subtitle: 'Revenue / transaction',
                                  icon: Icons.trending_up_rounded,
                                  iconColor: AppColors.success,
                                  colors: colors,
                                ),
                                _buildKpiCard(
                                  context: context,
                                  width: cardWidth,
                                  title: 'GST Collected',
                                  value:
                                      '₹${NumberFormat('#,##0').format(totalGst)}',
                                  subtitle:
                                      '${pakkaSales.length} Tax Invoices',
                                  icon: Icons.account_balance_outlined,
                                  iconColor: AppColors.accent,
                                  colors: colors,
                                ),
                                _buildKpiCard(
                                  context: context,
                                  width: cardWidth,
                                  title: 'Invoice Types',
                                  value:
                                      '${pakkaSales.length} / ${kacchaSales.length}',
                                  subtitle: 'Pakka vs Kaccha',
                                  icon: Icons.receipt_long_rounded,
                                  iconColor: AppColors.info,
                                  colors: colors,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Peak Sales Hours & Store Traffic (12AM - 11PM)
                        _buildPeakHoursCard(
                          context,
                          colors,
                          hourlyCounts,
                          peakHourLabel,
                        ),
                        const SizedBox(height: 20),

                        // Lower Sections:
                        // 1. Top Selling Items 🔥
                        _buildTopSellingCard(
                          context: context,
                          colors: colors,
                          items: topSelling,
                        ),
                        const SizedBox(height: 20),

                        // 2. Slow Moving Stock
                        _buildSlowMovingCard(
                          context: context,
                          colors: colors,
                          medicinesCount: medicines.length,
                          items: slowMoving,
                        ),
                        const SizedBox(height: 20),

                        // 3. Category Revenue Breakdown
                        _buildCategoryBreakdownCard(
                          context: context,
                          colors: colors,
                          categoryRevenue: categoryRevenue,
                          totalRevenue: totalRevenue,
                        ),
                        const SizedBox(height: 24),

                        // Return / Refund Action Banner
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showReturnRefundDialog(
                              context,
                              allSales,
                              db,
                              authUser?.uid ?? '',
                            ),
                            icon: const Icon(Icons.assignment_return_outlined,
                                size: 18, color: AppColors.warning),
                            label: Text(
                              'Process Return / Refund (Restock & Ledger Credit)',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                  color: AppColors.warning
                                      .withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Transaction Ledger Header & Search
                        Row(
                          children: [
                            Text(
                              'Sales Ledger & Invoices',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${displayTransactions.length} bills',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Search and Filter row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: colors.textPrimary),
                                decoration: InputDecoration(
                                  isDense: true,
                                  prefixIcon:
                                      const Icon(Icons.search, size: 18),
                                  hintText:
                                      'Search by bill #, customer, medicine...',
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: colors.surfaceLight),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButtonHideUnderline(
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10),
                                decoration: BoxDecoration(
                                  color: colors.surfaceLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedBillType,
                                  dropdownColor: colors.surfaceCard,
                                  icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'All', child: Text('All Bills')),
                                    DropdownMenuItem(
                                        value: 'pakka',
                                        child: Text('Pakka (+GST)')),
                                    DropdownMenuItem(
                                        value: 'kaccha', child: Text('Kaccha')),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _selectedBillType = v!),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Transactions List
                if (displayTransactions.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 48, color: colors.textHint),
                            const SizedBox(height: 8),
                            Text(
                              'No transactions found for $_selectedRange',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final sale = displayTransactions[i];
                          return _buildTransactionCard(
                              context, colors, sale, profile);
                        },
                        childCount: displayTransactions.length,
                      ),
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

  // Green Pill Export Button with Dropdown
  Widget _buildExportDropdown({
    required BuildContext context,
    required AppColors colors,
    required List<Sale> filteredSales,
    required dynamic profile,
    required List<Map<String, dynamic>> topSelling,
    required List<Map<String, dynamic>> slowMoving,
    required Map<String, double> categoryRevenue,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Export Reports',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colors.surfaceCard,
      onSelected: (val) {
        switch (val) {
          case 'print':
            _showPrintPreviewDialog(context, filteredSales, profile);
            break;
          case 'csv_sales':
            _exportSalesToCsv(context, filteredSales);
            break;
          case 'csv_top':
            _exportTopSellingToCsv(context, topSelling);
            break;
          case 'csv_slow':
            _exportSlowMovingToCsv(context, slowMoving);
            break;
          case 'csv_category':
            _exportCategoryBreakdownToCsv(context, categoryRevenue);
            break;
          case 'csv_all':
            _exportAllToCsv(
              context: context,
              sales: filteredSales,
              topSelling: topSelling,
              slowMoving: slowMoving,
              categoryRevenue: categoryRevenue,
            );
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'print',
          child: Row(
            children: [
              const Icon(Icons.print_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Export PDF & Print',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'csv_all',
          child: Row(
            children: [
              const Icon(Icons.table_chart_outlined,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Text('Export Excel / CSV (Full)',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'csv_sales',
          child: Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 18),
              const SizedBox(width: 10),
              Text('Sales Ledger CSV',
                  style: GoogleFonts.inter(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'csv_top',
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_outlined,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 10),
              Text('Top Selling Items CSV',
                  style: GoogleFonts.inter(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'csv_slow',
          child: Row(
            children: [
              const Icon(Icons.hourglass_empty_rounded, size: 18),
              const SizedBox(width: 10),
              Text('Slow Moving Stock CSV',
                  style: GoogleFonts.inter(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'csv_category',
          child: Row(
            children: [
              const Icon(Icons.pie_chart_outline_rounded, size: 18),
              const SizedBox(width: 10),
              Text('Category Revenue CSV',
                  style: GoogleFonts.inter(fontSize: 12)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.file_download_outlined,
                size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Export',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required BuildContext context,
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required AppColors colors,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: colors.textHint,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPeakHoursCard(
    BuildContext context,
    AppColors colors,
    List<int> hourlyCounts,
    String peakHourLabel,
  ) {
    final maxVal = hourlyCounts.fold<int>(1, (max, v) => v > max ? v : max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peak Sales Hours & Store Traffic',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Hourly customer order volume',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Peak: $peakHourLabel',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 24-hour distribution (12AM - 11PM)
          SizedBox(
            height: 95,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (i) {
                final count = hourlyCounts[i];
                final heightFactor = (count / maxVal).clamp(0.06, 1.0);
                final isPeak = count == maxVal && maxVal > 0;
                final hourLabel = i == 0
                    ? '12a'
                    : (i < 12
                        ? '${i}a'
                        : (i == 12 ? '12p' : '${i - 12}p'));

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Tooltip(
                      message: '$hourLabel: $count orders',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (count > 0)
                            Text(
                              '$count',
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: isPeak
                                    ? AppColors.primary
                                    : colors.textSecondary,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Container(
                            height: 55 * heightFactor,
                            decoration: BoxDecoration(
                              color: isPeak
                                  ? AppColors.primary
                                  : (count > 0
                                      ? AppColors.accent.withValues(alpha: 0.6)
                                      : colors.surfaceLight),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            // Show selected hour markers to prevent overlapping
                            (i % 3 == 0 || i == 23) ? hourLabel : '·',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight:
                                  isPeak ? FontWeight.w700 : FontWeight.w500,
                              color: isPeak
                                  ? AppColors.primary
                                  : colors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // Top Selling Items 🔥
  Widget _buildTopSellingCard({
    required BuildContext context,
    required AppColors colors,
    required List<Map<String, dynamic>> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Top Selling Items 🔥',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  tooltip: 'Export Top Selling CSV',
                  onPressed: () => _exportTopSellingToCsv(context, items),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No sales in this filter',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colors.textHint,
                  ),
                ),
              ),
            )
          else
            ...items.take(5).toList().asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surfaceLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : colors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$rank',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: rank <= 3
                              ? AppColors.primary
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            '${item['qty']} unit(s) sold',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${NumberFormat('#,##0').format(item['revenue'])}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // Slow Moving Stock
  Widget _buildSlowMovingCard({
    required BuildContext context,
    required AppColors colors,
    required int medicinesCount,
    required List<Map<String, dynamic>> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Slow Moving Stock',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              if (items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  tooltip: 'Export Slow Moving Stock CSV',
                  onPressed: () => _exportSlowMovingToCsv(context, items),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (medicinesCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No stock data',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colors.textHint,
                  ),
                ),
              ),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'All items are moving actively!',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.success,
                  ),
                ),
              ),
            )
          else
            ...items.take(5).map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surfaceLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.hourglass_empty_rounded,
                          size: 14, color: AppColors.warning),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            '${item['category']} • In stock: ${item['stock']} units',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item['qty']} sold',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // Category Revenue Breakdown
  Widget _buildCategoryBreakdownCard({
    required BuildContext context,
    required AppColors colors,
    required Map<String, double> categoryRevenue,
    required double totalRevenue,
  }) {
    final sortedCategories = categoryRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final palette = [
      AppColors.primary,
      AppColors.info,
      AppColors.accent,
      AppColors.success,
      AppColors.warning,
      Colors.indigo,
      Colors.purple,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category Revenue Breakdown',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Revenue share by product category',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (sortedCategories.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  tooltip: 'Export Category CSV',
                  onPressed: () =>
                      _exportCategoryBreakdownToCsv(context, categoryRevenue),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (sortedCategories.isEmpty || totalRevenue == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No revenue data for selected range',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colors.textHint,
                  ),
                ),
              ),
            )
          else
            ...sortedCategories.take(5).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final pct = totalRevenue > 0 ? (item.value / totalRevenue) : 0.0;
              final color = palette[idx % palette.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.key,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          '₹${NumberFormat('#,##0').format(item.value)} (${(pct * 100).toStringAsFixed(1)}%)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: colors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    AppColors colors,
    Sale sale,
    dynamic profile,
  ) {
    final isPakka = sale.isPakka;
    final isRefund = sale.billType == 'refund';
    final formattedDate = DateFormat('dd MMM, hh:mm a').format(sale.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.surfaceLight),
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => BillReceiptDialog(
              sale: sale,
              pharmacyName: profile?.pharmacyName ?? 'Klinixy Pharmacy',
              pharmacyAddress:
                  '${profile?.area ?? "Selaqui"}, ${profile?.city ?? "Dehradun"}',
              gstin: profile?.gstin,
              phone: profile?.phone,
            ),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isRefund
                    ? AppColors.error.withValues(alpha: 0.12)
                    : (isPakka
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.warning.withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isRefund
                    ? Icons.assignment_return_rounded
                    : (isPakka
                        ? Icons.receipt_long_rounded
                        : Icons.description_outlined),
                size: 20,
                color: isRefund
                    ? AppColors.error
                    : (isPakka ? AppColors.primary : AppColors.warning),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#${sale.billNo}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isRefund
                              ? AppColors.error.withValues(alpha: 0.15)
                              : (isPakka
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.warning.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isRefund
                              ? 'REFUND'
                              : (isPakka ? 'PAKKA (+GST)' : 'KACCHA'),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isRefund
                                ? AppColors.error
                                : (isPakka
                                    ? AppColors.success
                                    : AppColors.warning),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sale.customerName} • ${sale.items.length} item(s)',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: colors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style:
                        GoogleFonts.inter(fontSize: 10, color: colors.textHint),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${NumberFormat('#,##0').format(sale.totalPrice)}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isRefund ? AppColors.error : colors.textPrimary,
                  ),
                ),
                if (isPakka && !isRefund)
                  Text(
                    'GST: ₹${sale.taxAmount.toStringAsFixed(1)}',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.primary),
                  ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View Bill',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppColors.accent)),
                    const Icon(Icons.chevron_right,
                        size: 14, color: AppColors.accent),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Sale> _filterSalesByRange(
    List<Sale> sales,
    String range,
    DateTimeRange? customRange,
  ) {
    final now = DateTime.now();
    switch (range) {
      case 'Today':
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        return sales
            .where((s) =>
                s.date.isAfter(
                    todayStart.subtract(const Duration(milliseconds: 1))) &&
                s.date.isBefore(todayEnd))
            .toList();
      case '7 Days':
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        return sales
            .where((s) => s.date.isAfter(
                start.subtract(const Duration(milliseconds: 1))))
            .toList();
      case 'Month':
        final start = DateTime(now.year, now.month, 1);
        final nextMonth = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        return sales
            .where((s) =>
                s.date.isAfter(
                    start.subtract(const Duration(milliseconds: 1))) &&
                s.date.isBefore(nextMonth))
            .toList();
      case 'Year':
        final start = DateTime(now.year, 1, 1);
        final nextYear = DateTime(now.year + 1, 1, 1);
        return sales
            .where((s) =>
                s.date.isAfter(
                    start.subtract(const Duration(milliseconds: 1))) &&
                s.date.isBefore(nextYear))
            .toList();
      case 'Custom':
        if (customRange == null) return sales;
        final start = DateTime(customRange.start.year, customRange.start.month,
            customRange.start.day);
        final end = DateTime(customRange.end.year, customRange.end.month,
                customRange.end.day)
            .add(const Duration(days: 1));
        return sales
            .where((s) =>
                s.date.isAfter(
                    start.subtract(const Duration(milliseconds: 1))) &&
                s.date.isBefore(end))
            .toList();
      default:
        return sales;
    }
  }

  List<Map<String, dynamic>> _calculateTopSelling(List<Sale> sales) {
    final itemMap = <String, Map<String, dynamic>>{};
    for (final sale in sales) {
      if (sale.billType == 'refund') continue;
      for (final item in sale.items) {
        final key = item.medicineName.toLowerCase();
        if (!itemMap.containsKey(key)) {
          itemMap[key] = {
            'name': item.medicineName,
            'qty': 0,
            'revenue': 0.0,
          };
        }
        itemMap[key]!['qty'] =
            (itemMap[key]!['qty'] as int) + item.quantity;
        itemMap[key]!['revenue'] =
            (itemMap[key]!['revenue'] as double) + item.totalPrice;
      }
    }
    final list = itemMap.values.toList();
    list.sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
    return list;
  }

  List<Map<String, dynamic>> _calculateSlowMoving(
    List<Medicine> medicines,
    List<Sale> sales,
  ) {
    if (medicines.isEmpty) return [];

    final soldQuantities = <String, int>{};
    for (final sale in sales) {
      if (sale.billType == 'refund') continue;
      for (final item in sale.items) {
        final key = item.medicineId.isNotEmpty
            ? item.medicineId
            : item.medicineName.toLowerCase();
        soldQuantities[key] =
            (soldQuantities[key] ?? 0) + item.quantity;
      }
    }

    final slowMoving = <Map<String, dynamic>>[];
    for (final m in medicines) {
      if (m.stock > 0) {
        final sold = soldQuantities[m.id] ??
            soldQuantities[m.name.toLowerCase()] ??
            0;
        if (sold <= 2) {
          slowMoving.add({
            'name': m.name,
            'category': m.category,
            'stock': m.stock,
            'qty': sold,
          });
        }
      }
    }

    slowMoving.sort((a, b) {
      final qtyCompare = (a['qty'] as int).compareTo(b['qty'] as int);
      if (qtyCompare != 0) return qtyCompare;
      return (b['stock'] as int).compareTo(a['stock'] as int);
    });

    return slowMoving;
  }

  Map<String, double> _calculateCategoryRevenue(
    List<Sale> sales,
    List<Medicine> medicines,
  ) {
    final medCategoryMap = <String, String>{};
    for (final m in medicines) {
      medCategoryMap[m.id] = m.category;
      medCategoryMap[m.name.toLowerCase()] = m.category;
    }

    final result = <String, double>{};
    for (final sale in sales) {
      if (sale.billType == 'refund') continue;
      for (final item in sale.items) {
        final cat = medCategoryMap[item.medicineId] ??
            medCategoryMap[item.medicineName.toLowerCase()] ??
            'Other';
        result[cat] = (result[cat] ?? 0.0) + item.totalPrice;
      }
    }
    return result;
  }

  String _formatHourRange(int hour) {
    final ampm1 = hour >= 12 ? 'PM' : 'AM';
    final h1 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final nextH = (hour + 1) % 24;
    final ampm2 = nextH >= 12 ? 'PM' : 'AM';
    final h2 = nextH > 12 ? nextH - 12 : (nextH == 0 ? 12 : nextH);
    return '${h1.toString().padLeft(2, '0')}:00 $ampm1 - ${h2.toString().padLeft(2, '0')}:00 $ampm2';
  }

  // Multi-section CSV Exports following Pharma_<Section>_yyyyMMdd_HHmm.csv format
  void _exportSalesToCsv(BuildContext context, List<Sale> sales) {
    if (sales.isEmpty) {
      _showEmptyExportWarning(context, 'sales');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln(
        'Bill No,Date,Time,Customer Name,Bill Type,Items Count,Subtotal (INR),GST (INR),Grand Total (INR)');

    for (final s in sales) {
      final dateStr = DateFormat('yyyy-MM-dd').format(s.date);
      final timeStr = DateFormat('HH:mm:ss').format(s.date);
      final itemsSummary =
          s.items.map((i) => '${i.medicineName} (x${i.quantity})').join('; ');
      buffer.writeln(
        '"${s.billNo}","$dateStr","$timeStr","${s.customerName}","${s.billType}","$itemsSummary","${s.subtotal.toStringAsFixed(2)}","${s.taxAmount.toStringAsFixed(2)}","${s.totalPrice.toStringAsFixed(2)}"',
      );
    }

    final filename =
        'Pharma_Sales_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    exportCsv(buffer.toString(), filename);
    _showExportSuccess(context, filename);
  }

  void _exportTopSellingToCsv(
      BuildContext context, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      _showEmptyExportWarning(context, 'top selling items');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Rank,Medicine Name,Units Sold,Revenue (INR)');

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      buffer.writeln(
          '"#${i + 1}","${item['name']}","${item['qty']}","${(item['revenue'] as double).toStringAsFixed(2)}"');
    }

    final filename =
        'Pharma_TopProducts_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    exportCsv(buffer.toString(), filename);
    _showExportSuccess(context, filename);
  }

  void _exportSlowMovingToCsv(
      BuildContext context, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      _showEmptyExportWarning(context, 'slow moving stock');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Medicine Name,Category,Current Stock,Units Sold In Period');

    for (final item in items) {
      buffer.writeln(
          '"${item['name']}","${item['category']}","${item['stock']}","${item['qty']}"');
    }

    final filename =
        'Pharma_SlowMoving_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    exportCsv(buffer.toString(), filename);
    _showExportSuccess(context, filename);
  }

  void _exportCategoryBreakdownToCsv(
      BuildContext context, Map<String, double> categoryRevenue) {
    if (categoryRevenue.isEmpty) {
      _showEmptyExportWarning(context, 'category breakdown');
      return;
    }

    final total = categoryRevenue.values.fold<double>(0, (sum, v) => sum + v);
    final buffer = StringBuffer();
    buffer.writeln('Category,Revenue (INR),Share Percentage');

    for (final entry in categoryRevenue.entries) {
      final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
      buffer.writeln(
          '"${entry.key}","${entry.value.toStringAsFixed(2)}","${pct.toStringAsFixed(1)}%"');
    }

    final filename =
        'Pharma_CategoryBreakdown_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    exportCsv(buffer.toString(), filename);
    _showExportSuccess(context, filename);
  }

  void _exportAllToCsv({
    required BuildContext context,
    required List<Sale> sales,
    required List<Map<String, dynamic>> topSelling,
    required List<Map<String, dynamic>> slowMoving,
    required Map<String, double> categoryRevenue,
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    buffer.writeln('--- KLINIXY PHARMACY FINANCIAL REPORT ---');
    buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}');
    buffer.writeln('Period: $_selectedRange');
    buffer.writeln();

    // Section 1: Sales Ledger
    buffer.writeln('SECTION: SALES INVOICES');
    buffer.writeln(
        'Bill No,Date,Time,Customer,Type,Subtotal,Tax,Total');
    for (final s in sales) {
      buffer.writeln(
          '"${s.billNo}","${DateFormat('yyyy-MM-dd').format(s.date)}","${DateFormat('HH:mm').format(s.date)}","${s.customerName}","${s.billType}","${s.subtotal}","${s.taxAmount}","${s.totalPrice}"');
    }
    buffer.writeln();

    // Section 2: Top Selling
    buffer.writeln('SECTION: TOP SELLING ITEMS');
    buffer.writeln('Rank,Medicine Name,Units Sold,Revenue');
    for (int i = 0; i < topSelling.length; i++) {
      final t = topSelling[i];
      buffer.writeln('"#${i + 1}","${t['name']}","${t['qty']}","${t['revenue']}"');
    }
    buffer.writeln();

    // Section 3: Slow Moving
    buffer.writeln('SECTION: SLOW MOVING STOCK');
    buffer.writeln('Medicine Name,Category,Current Stock,Sold In Period');
    for (final s in slowMoving) {
      buffer.writeln('"${s['name']}","${s['category']}","${s['stock']}","${s['qty']}"');
    }
    buffer.writeln();

    // Section 4: Category Breakdown
    buffer.writeln('SECTION: CATEGORY BREAKDOWN');
    buffer.writeln('Category,Revenue');
    for (final c in categoryRevenue.entries) {
      buffer.writeln('"${c.key}","${c.value}"');
    }

    final filename =
        'Pharma_FullFinancialReport_${DateFormat('yyyyMMdd_HHmm').format(now)}.csv';
    exportCsv(buffer.toString(), filename);
    _showExportSuccess(context, filename);
  }

  void _showEmptyExportWarning(BuildContext context, String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No $type data to export for this period.')),
    );
  }

  void _showExportSuccess(BuildContext context, String filename) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported $filename successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showPrintPreviewDialog(
      BuildContext context, List<Sale> sales, dynamic profile) {
    final totalRev = sales.fold<double>(0, (sum, s) => sum + s.totalPrice);
    final totalGst = sales.fold<double>(0, (sum, s) => sum + s.taxAmount);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.print_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Financial Report Print Preview',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.pharmacyName ?? 'Klinixy Pharmacy',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Period: $_selectedRange  •  Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.grey[600]),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Completed Transactions:'),
                      Text('${sales.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Net Revenue:'),
                      Text('₹${NumberFormat('#,##0.00').format(totalRev)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total GST Collected (CGST + SGST):'),
                      Text('₹${NumberFormat('#,##0.00').format(totalGst)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Recent Bills Breakdown:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...sales.take(10).map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text('#${s.billNo}',
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 11)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(s.customerName,
                                    style: const TextStyle(fontSize: 11),
                                    maxLines: 1)),
                            Text('₹${s.totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await PrinterService.printSalesReport(
                    sales: sales,
                    rangeLabel: _selectedRange,
                    pharmacyName:
                        profile?.pharmacyName ?? 'Klinixy Pharmacy',
                    pharmacyAddress: profile != null
                        ? '${profile.area}, ${profile.city}'
                        : 'Dehradun, Selaqui',
                    gstin: profile?.gstin,
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Print error: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Print Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showReturnRefundDialog(
    BuildContext context,
    List<Sale> allSales,
    DatabaseService? db,
    String uid,
  ) {
    final validSales = allSales
        .where((s) => s.billType != 'refund' && s.totalPrice > 0)
        .toList();
    if (validSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No completed sales found to refund against.')),
      );
      return;
    }

    Sale? selectedSale;
    final Map<String, int> returnQuantities = {};
    final reasonCtrl = TextEditingController(text: 'Customer return');

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            'Process Customer Return & Refund',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select the original Bill Number to process return:',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'Original Bill *'),
                    items: validSales
                        .take(20)
                        .map((s) => DropdownMenuItem(
                              value: s.billNo,
                              child: Text(
                                  '#${s.billNo} — ₹${s.totalPrice.toStringAsFixed(2)} (${s.customerName})'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setDlgState(() {
                        selectedSale =
                            validSales.firstWhere((s) => s.billNo == val);
                        returnQuantities.clear();
                        for (final item in selectedSale!.items) {
                          returnQuantities[item.medicineId] = item.quantity;
                        }
                      });
                    },
                  ),
                  if (selectedSale != null) ...[
                    const SizedBox(height: 14),
                    const Divider(),
                    Text('Select Items to Return:',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...selectedSale!.items.map((item) {
                      final currentQty =
                          returnQuantities[item.medicineId] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.medicineName} (Max: ${item.quantity})',
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 20),
                              onPressed: currentQty > 0
                                  ? () => setDlgState(() =>
                                      returnQuantities[item.medicineId] =
                                          currentQty - 1)
                                  : null,
                            ),
                            Text('$currentQty',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 20),
                              onPressed: currentQty < item.quantity
                                  ? () => setDlgState(() =>
                                      returnQuantities[item.medicineId] =
                                          currentQty + 1)
                                  : null,
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reason for Return *',
                        hintText:
                            'e.g. Prescribed dosage changed by physician',
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
              onPressed: selectedSale == null ||
                      returnQuantities.values.every((q) => q == 0)
                  ? null
                  : () async {
                      if (db == null) return;
                      final itemsToReturn = <SaleItem>[];
                      for (final item in selectedSale!.items) {
                        final q = returnQuantities[item.medicineId] ?? 0;
                        if (q > 0) {
                          itemsToReturn.add(SaleItem(
                            medicineId: item.medicineId,
                            medicineName: item.medicineName,
                            quantity: q,
                            unitPrice: item.unitPrice,
                            totalPrice: item.unitPrice * q,
                            hsn: item.hsn,
                            gstSlab: item.gstSlab,
                            taxAmount: selectedSale!.isPakka
                                ? (item.unitPrice *
                                    q *
                                    (item.gstSlab / 100.0))
                                : 0.0,
                          ));
                        }
                      }

                      Navigator.pop(dlgCtx);
                      try {
                        await db.processReturn(
                          originalSale: selectedSale!,
                          returnedItems: itemsToReturn,
                          reason: reasonCtrl.text.trim(),
                          byUid: uid,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Refund processed! Stock restocked and ledger updated.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Refund failed: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Confirm Return & Restock'),
            ),
          ],
        ),
      ),
    );
  }
}
