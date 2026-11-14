import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../models/sale.dart';
import '../models/medicine.dart';
import '../widgets/bill_receipt_dialog.dart';
import '../utils/csv_export.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String _selectedRange = 'Today';
  final _ranges = ['Today', 'Last 7 Days', 'This Month', 'All Time'];
  String _searchQuery = '';
  String _selectedBillType = 'All'; // 'All', 'pakka', 'kaccha'

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final salesAsync = ref.watch(salesStreamProvider);
    final medicinesAsync = ref.watch(medicinesStreamProvider);
    final profile = ref.watch(pharmacyProfileProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: salesAsync.when(
          data: (allSales) {
            final filteredSales = _filterSalesByRange(allSales, _selectedRange);
            final medicines = medicinesAsync.valueOrNull ?? [];

            // Math calculations
            final totalRevenue = filteredSales.fold<double>(0, (sum, s) => sum + s.totalPrice);
            final totalGst = filteredSales
                .where((s) => s.isPakka)
                .fold<double>(0, (sum, s) => sum + s.taxAmount);
            final totalOrders = filteredSales.length;
            final avgOrderValue = totalOrders > 0 ? (totalRevenue / totalOrders) : 0.0;

            // Hourly distribution for peak hours (09:00 - 21:00)
            final hourlyCounts = List<int>.filled(13, 0); // 9am (0) to 9pm (12)
            for (final sale in filteredSales) {
              final h = sale.date.hour;
              if (h >= 9 && h <= 21) {
                hourlyCounts[h - 9] += 1;
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
            final peakHourLabel = _formatHourRange(maxHourIdx + 9);

            // Category breakdown
            final categoryRevenue = _calculateCategoryRevenue(filteredSales, medicines);

            // Transaction search & filter
            final displayTransactions = filteredSales.where((s) {
              final matchesQuery = _searchQuery.isEmpty ||
                  s.billNo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  s.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  s.medicineName.toLowerCase().contains(_searchQuery.toLowerCase());
              final matchesType = _selectedBillType == 'All' || s.billType == _selectedBillType;
              return matchesQuery && matchesType;
            }).toList();

            return CustomScrollView(
              slivers: [
                // App Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enterprise Analytics & Financial Report',
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'View peak sales hours, top products & custom metrics',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Filter Presets & Action Buttons
                        Row(
                          children: [
                            // Date Range Presets
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _ranges.map((r) {
                                    final isSelected = _selectedRange == r;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(r),
                                        selected: isSelected,
                                        selectedColor: AppColors.primary,
                                        backgroundColor: colors.surfaceLight,
                                        labelStyle: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? Colors.white : colors.textSecondary,
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(
                                            color: isSelected ? AppColors.primary : Colors.transparent,
                                          ),
                                        ),
                                        onSelected: (_) => setState(() => _selectedRange = r),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Export CSV & PDF Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _exportToCsv(context, filteredSales),
                                icon: const Icon(Icons.file_download_outlined, size: 18),
                                label: Text(
                                  'Export Excel / CSV',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: BorderSide(color: colors.surfaceLight),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showPrintPreviewDialog(context, filteredSales, profile),
                                icon: const Icon(Icons.print_outlined, size: 18),
                                label: Text(
                                  'Export PDF & Print',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 4 KPI Cards Grid
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 600;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildKpiCard(
                                  context: context,
                                  width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
                                  title: 'Total Revenue (INR)',
                                  value: '₹${NumberFormat('#,##0').format(totalRevenue)}',
                                  subtitle: 'Gross sales ($_selectedRange)',
                                  icon: Icons.currency_rupee_rounded,
                                  iconColor: AppColors.primary,
                                  colors: colors,
                                ),
                                _buildKpiCard(
                                  context: context,
                                  width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
                                  title: 'Total GST (INR)',
                                  value: '₹${NumberFormat('#,##0').format(totalGst)}',
                                  subtitle: '18% GST on Pakka Bills',
                                  icon: Icons.account_balance_outlined,
                                  iconColor: AppColors.accent,
                                  colors: colors,
                                ),
                                _buildKpiCard(
                                  context: context,
                                  width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
                                  title: 'Total Sales Count',
                                  value: '$totalOrders',
                                  subtitle: '${filteredSales.where((s) => s.isPakka).length} Pakka • ${filteredSales.where((s) => !s.isPakka).length} Kaccha',
                                  icon: Icons.receipt_long_rounded,
                                  iconColor: AppColors.accent,
                                  colors: colors,
                                ),
                                _buildKpiCard(
                                  context: context,
                                  width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
                                  title: 'Avg Order Value',
                                  value: '₹${NumberFormat('#,##0').format(avgOrderValue)}',
                                  subtitle: 'Per transaction average',
                                  icon: Icons.trending_up_rounded,
                                  iconColor: AppColors.success,
                                  colors: colors,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Peak Sales Hours & Store Traffic
                        _buildPeakHoursCard(context, colors, hourlyCounts, maxHourVal > 0 ? peakHourLabel : 'N/A'),
                        const SizedBox(height: 20),

                        // Category Revenue Breakdown
                        if (categoryRevenue.isNotEmpty) ...[
                          _buildCategoryBreakdownCard(context, colors, categoryRevenue, totalRevenue),
                          const SizedBox(height: 20),
                        ],

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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                                onChanged: (v) => setState(() => _searchQuery = v),
                                style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary),
                                decoration: InputDecoration(
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.search, size: 18),
                                  hintText: 'Search by bill #, customer, medicine...',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: colors.surfaceLight),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButtonHideUnderline(
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: colors.surfaceLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedBillType,
                                  dropdownColor: colors.surfaceCard,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'All', child: Text('All Bills')),
                                    DropdownMenuItem(value: 'pakka', child: Text('Pakka (+GST)')),
                                    DropdownMenuItem(value: 'kaccha', child: Text('Kaccha')),
                                  ],
                                  onChanged: (v) => setState(() => _selectedBillType = v!),
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
                            Icon(Icons.receipt_long_outlined, size: 48, color: colors.textHint),
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
                          return _buildTransactionCard(context, colors, sale, profile);
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
                    'Hourly customer order volume (09:00 - 21:00)',
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
                    const Icon(Icons.flash_on_rounded, size: 14, color: AppColors.primary),
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

          // Hourly distribution bars
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(hourlyCounts.length, (i) {
                final count = hourlyCounts[i];
                final hourNum = i + 9;
                final heightFactor = (count / maxVal).clamp(0.08, 1.0);
                final isPeak = count == maxVal && maxVal > 0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (count > 0)
                          Text(
                            '$count',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isPeak ? AppColors.primary : colors.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Container(
                          height: 55 * heightFactor,
                          decoration: BoxDecoration(
                            color: isPeak
                                ? AppColors.primary
                                : (count > 0 ? AppColors.accent.withValues(alpha: 0.6) : colors.surfaceLight),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${hourNum > 12 ? hourNum - 12 : hourNum}${hourNum >= 12 ? 'p' : 'a'}',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
                            color: isPeak ? AppColors.primary : colors.textHint,
                          ),
                        ),
                      ],
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

  Widget _buildCategoryBreakdownCard(
    BuildContext context,
    AppColors colors,
    Map<String, double> categoryRevenue,
    double totalRevenue,
  ) {
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
          const SizedBox(height: 14),
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
              pharmacyName: profile?.pharmacyName ?? 'Test',
              pharmacyAddress: '${profile?.area ?? "Selaqui"}, ${profile?.city ?? "Dehradun"}',
            ),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPakka
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPakka ? Icons.receipt_long_rounded : Icons.description_outlined,
                size: 20,
                color: isPakka ? AppColors.primary : AppColors.warning,
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isPakka
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPakka ? 'PAKKA (+GST)' : 'KACCHA',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isPakka ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sale.customerName} • ${sale.items.length} item(s)',
                    style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: GoogleFonts.inter(fontSize: 10, color: colors.textHint),
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
                    color: colors.textPrimary,
                  ),
                ),
                if (isPakka)
                  Text(
                    'GST: ₹${sale.taxAmount.toStringAsFixed(1)}',
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.primary),
                  ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View Bill', style: GoogleFonts.inter(fontSize: 10, color: AppColors.accent)),
                    const Icon(Icons.chevron_right, size: 14, color: AppColors.accent),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Sale> _filterSalesByRange(List<Sale> sales, String range) {
    final now = DateTime.now();
    switch (range) {
      case 'Today':
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        return sales.where((s) => DateFormat('yyyy-MM-dd').format(s.date) == todayStr).toList();
      case 'Last 7 Days':
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        return sales.where((s) => s.date.isAfter(sevenDaysAgo)).toList();
      case 'This Month':
        final monthStr = DateFormat('yyyy-MM').format(now);
        return sales.where((s) => DateFormat('yyyy-MM').format(s.date) == monthStr).toList();
      case 'All Time':
      default:
        return sales;
    }
  }

  Map<String, double> _calculateCategoryRevenue(List<Sale> sales, List<Medicine> medicines) {
    final medCategoryMap = <String, String>{};
    for (final m in medicines) {
      medCategoryMap[m.id] = m.category;
      medCategoryMap[m.name.toLowerCase()] = m.category;
    }

    final result = <String, double>{};
    for (final sale in sales) {
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
    final h1 = hour > 12 ? hour - 12 : hour;
    final nextH = hour + 1;
    final ampm2 = nextH >= 12 ? 'PM' : 'AM';
    final h2 = nextH > 12 ? nextH - 12 : nextH;
    return '${h1.toString().padLeft(2, '0')}:00 $ampm1 - ${h2.toString().padLeft(2, '0')}:00 $ampm2';
  }

  void _exportToCsv(BuildContext context, List<Sale> sales) {
    if (sales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sales records to export for this period.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Bill No,Date,Time,Customer Name,Bill Type,Items Count,Subtotal (INR),GST (INR),Grand Total (INR)');

    for (final s in sales) {
      final dateStr = DateFormat('yyyy-MM-dd').format(s.date);
      final timeStr = DateFormat('HH:mm:ss').format(s.date);
      final itemsSummary = s.items.map((i) => '${i.medicineName} (x${i.quantity})').join('; ');
      buffer.writeln(
        '"${s.billNo}","$dateStr","$timeStr","${s.customerName}","${s.billType}","$itemsSummary","${s.subtotal.toStringAsFixed(2)}","${s.taxAmount.toStringAsFixed(2)}","${s.totalPrice.toStringAsFixed(2)}"',
      );
    }

    final filename = 'Pharma_Sales_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    exportCsv(buffer.toString(), filename);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported $filename successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showPrintPreviewDialog(BuildContext context, List<Sale> sales, dynamic profile) {
    final totalRev = sales.fold<double>(0, (sum, s) => sum + s.totalPrice);
    final totalGst = sales.fold<double>(0, (sum, s) => sum + s.taxAmount);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.print_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Financial Report Print Preview',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
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
                    profile?.pharmacyName ?? 'Test Pharmacy',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Period: $_selectedRange  •  Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Completed Transactions:'),
                      Text('${sales.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      const Text('Total GST Collected (18%):'),
                      Text('₹${NumberFormat('#,##0.00').format(totalGst)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Recent Bills Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...sales.take(10).map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text('#${s.billNo}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(s.customerName, style: const TextStyle(fontSize: 11), maxLines: 1)),
                            Text('₹${s.totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
              onPressed: () {
                Navigator.pop(ctx);
                BillReceiptDialog.printDocument(context);
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
}
