import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../services/database_service.dart';
import '../models/medicine.dart';
import '../widgets/skeleton_loader.dart';
import 'purchase_orders_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'All';
  String _sortBy = 'name'; // name, price, stock, expiry
  bool _sortAscending = true;
  late AnimationController _fabAnimController;

  static const List<Map<String, dynamic>> _categoryChips = [
    {'name': 'All', 'icon': Icons.apps_rounded},
    {'name': 'Tablets', 'icon': Icons.medication_rounded},
    {'name': 'Capsules', 'icon': Icons.medication_liquid_rounded},
    {'name': 'Pain Relief', 'icon': Icons.healing_rounded},
    {'name': 'Antibiotics', 'icon': Icons.science_rounded},
    {'name': 'Allergy', 'icon': Icons.air_rounded},
    {'name': 'Diabetes', 'icon': Icons.bloodtype_rounded},
    {'name': 'Syrups', 'icon': Icons.local_drink_rounded},
    {'name': 'Injections', 'icon': Icons.vaccines_rounded},
    {'name': 'Ointments', 'icon': Icons.spa_rounded},
    {'name': 'Drops', 'icon': Icons.water_drop_rounded},
    {'name': 'Inhalers', 'icon': Icons.air_rounded},
    {'name': 'Vaccines', 'icon': Icons.health_and_safety_rounded},
    {'name': 'Herbal', 'icon': Icons.eco_rounded},
    {'name': 'Supplements', 'icon': Icons.fitness_center_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimController.forward();
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  List<Medicine> _sortMedicines(List<Medicine> meds) {
    final sorted = List<Medicine>.from(meds);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'price':
          cmp = a.price.compareTo(b.price);
          break;
        case 'stock':
          cmp = a.stock.compareTo(b.stock);
          break;
        case 'expiry':
          cmp = a.expiryDate.compareTo(b.expiryDate);
          break;
        default:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medicinesAsync = ref.watch(medicinesStreamProvider);
    final searchQuery = ref.watch(inventorySearchProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: medicinesAsync.when(
          data: (medicines) {
            final filtered = medicines.where((m) {
              final matchesQuery = searchQuery.isEmpty ||
                  m.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  m.genericName
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()) ||
                  m.category
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()) ||
                  m.manufacturer
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()) ||
                  m.batchNo
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase());
              final matchesCategory = _selectedCategory == 'All' ||
                  m.category.toLowerCase() ==
                      _selectedCategory.toLowerCase() ||
                  m.name
                      .toLowerCase()
                      .contains(_selectedCategory.toLowerCase());
              return matchesQuery && matchesCategory;
            }).toList();

            final sortedList = _sortMedicines(filtered);

            // Quick stats
            final totalItems = medicines.length;
            final lowStockCount =
                medicines.where((m) => m.isLowStock && !m.isExpired).length;
            final expiringCount =
                medicines.where((m) => m.isExpiringSoon || m.isExpired).length;
            final totalValue = medicines.fold<double>(
                0, (sum, m) => sum + (m.price * m.stock));

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1360),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 950;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Header ─────────────────────────────────
                        _buildHeader(context, colors, isDark, totalItems,
                            lowStockCount, expiringCount, totalValue, isDesktop),
                        const SizedBox(height: 14),

                        // ─── Search & Sort Bar ──────────────────────
                        _buildSearchSortBar(context, colors, isDark),
                        const SizedBox(height: 10),

                        // ─── Category Chips ─────────────────────────
                        _buildCategoryChips(colors, isDark),
                        const SizedBox(height: 10),

                        // ─── Results info ───────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${sortedList.length} of $totalItems items',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () => ref
                                      .read(inventorySearchProvider.notifier)
                                      .set(''),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.error
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.close,
                                            size: 12, color: AppColors.error),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Clear search',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ─── Medicine List / Grid ───────────────────
                        Expanded(
                          child: sortedList.isEmpty
                              ? _buildEmptyState(colors)
                              : isDesktop
                                  ? _buildDesktopGrid(
                                      sortedList, colors, isDark)
                                  : _buildMobileList(
                                      sortedList, colors, isDark),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
          loading: () => const InventorySkeleton(),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load inventory',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$err',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabAnimController,
          curve: Curves.elasticOut,
        ),
        child: FloatingActionButton.extended(
          heroTag: 'inventory_fab',
          onPressed: () => _showAddMedicineSheet(context),
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(
            'Add Medicine',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, fontSize: 13),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ─── Header with Quick Stats ──────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    AppColors colors,
    bool isDark,
    int totalItems,
    int lowStockCount,
    int expiringCount,
    double totalValue,
    bool isDesktop,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isDesktop ? 32 : 20, 20, isDesktop ? 32 : 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory',
                      style: GoogleFonts.inter(
                        fontSize: isDesktop ? 28 : 24,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage your medicine catalog, stock levels & reorders',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PurchaseOrdersScreen()),
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 14),
                label: Text(
                  'POs & Vendors',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(
                      color: colors.textSecondary.withValues(alpha: 0.3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick stat pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatPill(
                  icon: Icons.inventory_2_rounded,
                  label: 'Total',
                  value: '$totalItems',
                  color: AppColors.primary,
                  colors: colors,
                ),
                const SizedBox(width: 8),
                _buildStatPill(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Value',
                  value: '₹${NumberFormat.compact().format(totalValue)}',
                  color: AppColors.accent,
                  colors: colors,
                ),
                const SizedBox(width: 8),
                _buildStatPill(
                  icon: Icons.warning_amber_rounded,
                  label: 'Low Stock',
                  value: '$lowStockCount',
                  color: lowStockCount > 0 ? AppColors.warning : AppColors.success,
                  colors: colors,
                ),
                const SizedBox(width: 8),
                _buildStatPill(
                  icon: Icons.timer_outlined,
                  label: 'Expiring',
                  value: '$expiringCount',
                  color: expiringCount > 0 ? AppColors.error : AppColors.success,
                  colors: colors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Search & Sort Bar ────────────────────────────────────────────────────
  Widget _buildSearchSortBar(BuildContext context, AppColors colors, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: colors.textHint.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) =>
                    ref.read(inventorySearchProvider.notifier).set(v),
                style: GoogleFonts.inter(
                    fontSize: 13, color: colors.textPrimary),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: colors.textHint),
                  hintText: 'Search by name, generic, batch, manufacturer...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 12, color: colors.textHint),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildSortButton(colors, isDark),
        ],
      ),
    );
  }

  Widget _buildSortButton(AppColors colors, bool isDark) {
    return PopupMenuButton<String>(
      onSelected: (val) {
        setState(() {
          if (_sortBy == val) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = val;
            _sortAscending = true;
          }
        });
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: colors.surfaceCard,
      elevation: 8,
      itemBuilder: (_) => [
        _sortMenuItem('name', 'Name', Icons.sort_by_alpha_rounded, colors),
        _sortMenuItem('price', 'Price', Icons.currency_rupee_rounded, colors),
        _sortMenuItem('stock', 'Stock', Icons.inventory_rounded, colors),
        _sortMenuItem('expiry', 'Expiry Date', Icons.timer_outlined, colors),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: colors.textHint.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.sort_rounded, size: 20, color: colors.textSecondary),
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(
      String value, String label, IconData icon, AppColors colors) {
    final isActive = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: isActive ? AppColors.primary : colors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? AppColors.primary : colors.textPrimary,
            ),
          ),
          const Spacer(),
          if (isActive)
            Icon(
              _sortAscending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 14,
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }

  // ─── Category Chips ───────────────────────────────────────────────────────
  Widget _buildCategoryChips(AppColors colors, bool isDark) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _categoryChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final chip = _categoryChips[idx];
          final cat = chip['name'] as String;
          final icon = chip['icon'] as IconData;
          final isSelected = _selectedCategory == cat;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: AppColors.primaryGradient)
                    : null,
                color: isSelected ? null : colors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? null
                    : Border.all(
                        color: colors.textHint.withValues(alpha: 0.15)),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color:
                              AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : colors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    cat,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────
  Widget _buildEmptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.accent.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'No medicines found',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "+ Add Medicine" to register your first item',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Desktop Grid View ────────────────────────────────────────────────────
  Widget _buildDesktopGrid(
      List<Medicine> meds, AppColors colors, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: 195,
      ),
      itemCount: meds.length,
      itemBuilder: (_, i) => _buildMedicineCard(context, meds[i], colors, isDark),
    );
  }

  // ─── Mobile List View ─────────────────────────────────────────────────────
  Widget _buildMobileList(
      List<Medicine> meds, AppColors colors, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: meds.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildMedicineCard(context, meds[i], colors, isDark),
      ),
    );
  }

  // ─── Medicine Card ────────────────────────────────────────────────────────
  Widget _buildMedicineCard(
      BuildContext context, Medicine med, AppColors colors, bool isDark) {
    final isLow = med.isLowStock && !med.isExpired;
    final isExp = med.isExpired;
    final isExpSoon = med.isExpiringSoon;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isExp) {
      statusColor = AppColors.error;
      statusLabel = 'EXPIRED';
      statusIcon = Icons.error_rounded;
    } else if (isExpSoon) {
      statusColor = AppColors.warning;
      statusLabel = 'EXP SOON';
      statusIcon = Icons.schedule_rounded;
    } else if (isLow) {
      statusColor = AppColors.warning;
      statusLabel = 'LOW STOCK';
      statusIcon = Icons.trending_down_rounded;
    } else {
      statusColor = AppColors.success;
      statusLabel = 'IN STOCK';
      statusIcon = Icons.check_circle_rounded;
    }

    return GestureDetector(
      onTap: () => _showMedicineDetail(context, med),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExp
                ? AppColors.error.withValues(alpha: 0.3)
                : isLow
                    ? AppColors.warning.withValues(alpha: 0.2)
                    : colors.textHint.withValues(alpha: 0.08),
            width: isExp || isLow ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Name + Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category icon badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isExp
                          ? [AppColors.error, AppColors.error.withValues(alpha: 0.7)]
                          : isLow
                              ? AppColors.warmGradient
                              : AppColors.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(med.category),
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (med.genericName.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          med.genericName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: colors.textHint,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${med.price.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    if (med.costPrice > 0 && med.profitMargin > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '+${med.profitMargin.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tags row
            Row(
              children: [
                _buildTag(med.category, colors.surfaceLight,
                    colors.textSecondary, colors),
                const SizedBox(width: 6),
                _buildTag(statusLabel, statusColor.withValues(alpha: 0.12),
                    statusColor, colors,
                    icon: statusIcon),
                if (med.rxRequired) ...[
                  const SizedBox(width: 6),
                  _buildTag(
                      'Rx',
                      AppColors.accent.withValues(alpha: 0.12),
                      AppColors.accent,
                      colors),
                ],
                const Spacer(),
                // Stock count
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isLow || isExp)
                        ? statusColor.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${med.stock} units',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: (isLow || isExp) ? statusColor : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bottom Actions
            Row(
              children: [
                Expanded(
                  child: _buildActionBtn(
                    icon: Icons.add_rounded,
                    label: 'Stock In',
                    color: AppColors.success,
                    onTap: () => _showStockAdjustmentDialog(context, med,
                        isStockIn: true),
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionBtn(
                    icon: Icons.remove_rounded,
                    label: 'Stock Out',
                    color: AppColors.warning,
                    onTap: () => _showStockAdjustmentDialog(context, med,
                        isStockIn: false),
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionBtn(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: AppColors.accent,
                  onTap: () => _showEditMedicineSheet(context, med),
                  colors: colors,
                  compact: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(
      String text, Color bgColor, Color fgColor, AppColors colors,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fgColor),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required AppColors colors,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 0,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    for (final chip in _categoryChips) {
      if ((chip['name'] as String).toLowerCase() == category.toLowerCase()) {
        return chip['icon'] as IconData;
      }
    }
    return Icons.medication_rounded;
  }

  // ─── Stock Adjustment Dialog ──────────────────────────────────────────────
  void _showStockAdjustmentDialog(BuildContext context, Medicine med,
      {required bool isStockIn}) {
    final colors = AppColors.of(context);
    final qtyCtrl = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textHint.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isStockIn
                          ? [AppColors.success, const Color(0xFF43A047)]
                          : AppColors.warmGradient,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isStockIn
                        ? Icons.add_rounded
                        : Icons.remove_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isStockIn ? 'Stock In' : 'Stock Out',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        med.name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Current: ${med.stock}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.inter(
                    fontSize: 24, color: colors.textHint),
                filled: true,
                fillColor: colors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 20),
              ),
            ),
            const SizedBox(height: 14),
            // Quick preset row
            Row(
              children: [5, 10, 25, 50, 100].map((q) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () => qtyCtrl.text = '$q',
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '+$q',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                  if (qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Enter a valid quantity > 0')),
                    );
                    return;
                  }
                  if (!isStockIn && med.stock < qty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Cannot remove $qty — only ${med.stock} in stock'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final db = ref.read(databaseServiceProvider);
                  if (db != null) {
                    final delta = isStockIn ? qty : -qty;
                    await db.adjustStock(med.id, delta);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isStockIn
                              ? '${med.name} stock +$qty'
                              : '${med.name} stock -$qty'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isStockIn ? AppColors.success : AppColors.warning,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  isStockIn ? 'Add Stock' : 'Remove Stock',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Medicine Detail Bottom Sheet ─────────────────────────────────────────
  void _showMedicineDetail(BuildContext context, Medicine med) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textHint.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: AppColors.primaryGradient),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _getCategoryIcon(med.category),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med.name,
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (med.genericName.isNotEmpty)
                                Text(
                                  med.genericName,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: colors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${med.price.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _detailRow('Category', med.category, colors),
                          _detailRow('HSN Code', med.hsn, colors),
                          _detailRow('GST Slab', '${med.gstSlab}%', colors),
                          _detailRow(
                              'Batch',
                              med.batchNo.isNotEmpty ? med.batchNo : '—',
                              colors),
                          _detailRow(
                              'Rack / Shelf',
                              med.rackShelf.isNotEmpty
                                  ? med.rackShelf
                                  : '—',
                              colors),
                          _detailRow(
                              'Prescription',
                              med.rxRequired ? 'Schedule H Required' : 'OTC',
                              colors),
                          _detailRow(
                              'Manufacturer',
                              med.manufacturer.isNotEmpty
                                  ? med.manufacturer
                                  : '—',
                              colors),
                          _detailRow('Stock', '${med.stock} units', colors),
                          _detailRow('Min Safe Stock',
                              '${med.reorderLevel} units', colors),
                          _detailRow('Cost Price',
                              '₹${med.costPrice.toStringAsFixed(2)}', colors),
                          _detailRow(
                              'Profit Margin',
                              '${med.profitMargin.toStringAsFixed(1)}%',
                              colors),
                          _detailRow(
                              'Expiry Date',
                              DateFormat('dd MMM yyyy')
                                  .format(med.expiryDate),
                              colors),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditMedicineSheet(context, med);
                            },
                            icon:
                                const Icon(Icons.edit_outlined, size: 18),
                            label: Text(
                              'Edit',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmDelete(context, med);
                            },
                            icon: const Icon(Icons.delete_outline,
                                size: 18),
                            label: Text(
                              'Delete',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style:
                GoogleFonts.inter(fontSize: 13, color: colors.textSecondary)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary)),
      ]),
    );
  }

  void _confirmDelete(BuildContext context, Medicine med) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Medicine',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Permanently delete "${med.name}" from inventory? This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = ref.read(databaseServiceProvider);
              if (db != null) {
                await db.deleteMedicine(med.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Medicine deleted.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ─── Professional Add Medicine Sheet ──────────────────────────────────────
  void _showAddMedicineSheet(BuildContext context) {
    _showMedicineFormSheet(context, null);
  }

  void _showEditMedicineSheet(BuildContext context, Medicine med) {
    _showMedicineFormSheet(context, med);
  }

  void _showMedicineFormSheet(BuildContext context, Medicine? existing) {
    final colors = AppColors.of(context);
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final genericCtrl =
        TextEditingController(text: existing?.genericName ?? '');
    final manufacturerCtrl =
        TextEditingController(text: existing?.manufacturer ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? existing.price.toString() : '');
    final costCtrl = TextEditingController(
        text: existing != null && existing.costPrice > 0
            ? existing.costPrice.toString()
            : '');
    final stockCtrl = TextEditingController(
        text: existing != null ? existing.stock.toString() : '50');
    final minStockCtrl = TextEditingController(
        text: existing?.reorderLevel.toString() ?? '10');
    final hsnCtrl =
        TextEditingController(text: existing?.hsn ?? '3004');
    final batchCtrl =
        TextEditingController(text: existing?.batchNo ?? '');
    final rackCtrl =
        TextEditingController(text: existing?.rackShelf ?? '');

    String selectedCat = existing?.category ??
        (_selectedCategory != 'All' ? _selectedCategory : 'Tablets');
    int gstSlab = existing?.gstSlab ?? 12;
    bool rxRequired = existing?.rxRequired ?? false;
    DateTime expiryDate =
        existing?.expiryDate ?? DateTime.now().add(const Duration(days: 365));
    bool isSaving = false;

    final categories = _categoryChips
        .where((c) => c['name'] != 'All')
        .map((c) => c['name'] as String)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Sheet Header ──────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.primaryGradient,
                    ),
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isEdit
                                  ? Icons.edit_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit
                                      ? 'Edit Medicine'
                                      : 'Add New Medicine',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  isEdit
                                      ? 'Update details for ${existing.name}'
                                      : 'Register a new item to your inventory',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ─── Form Body ─────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24, 20, 24,
                        MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section: Basic Info
                          _sectionTitle('Basic Information', colors),
                          const SizedBox(height: 10),
                          _formField(
                            controller: nameCtrl,
                            label: 'Medicine Name',
                            hint: 'e.g. Paracetamol 500mg',
                            icon: Icons.medication_rounded,
                            required: true,
                            colors: colors,
                          ),
                          const SizedBox(height: 12),
                          _formField(
                            controller: genericCtrl,
                            label: 'Generic / Salt Name',
                            hint: 'e.g. Acetaminophen',
                            icon: Icons.science_rounded,
                            colors: colors,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: categories.contains(selectedCat)
                                      ? selectedCat
                                      : categories.first,
                                  decoration: InputDecoration(
                                    labelText: 'Category',
                                    prefixIcon: const Icon(
                                        Icons.category_rounded,
                                        size: 18),
                                    filled: true,
                                    fillColor: colors.surfaceLight,
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 12),
                                  ),
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: colors.textPrimary),
                                  items: categories
                                      .map((c) => DropdownMenuItem(
                                          value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setSheetState(() => selectedCat = v!),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _formField(
                                  controller: manufacturerCtrl,
                                  label: 'Manufacturer',
                                  hint: 'e.g. Cipla',
                                  icon: Icons.business_rounded,
                                  colors: colors,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Section: Pricing
                          _sectionTitle('Pricing & Stock', colors),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _formField(
                                  controller: priceCtrl,
                                  label: 'Selling Price (₹)',
                                  hint: '0.00',
                                  icon: Icons.currency_rupee_rounded,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  required: true,
                                  colors: colors,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _formField(
                                  controller: costCtrl,
                                  label: 'Cost Price (₹)',
                                  hint: '0.00',
                                  icon: Icons.receipt_long_rounded,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  colors: colors,
                                ),
                              ),
                            ],
                          ),
                          if (!isEdit) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _formField(
                                    controller: stockCtrl,
                                    label: 'Initial Stock',
                                    hint: '50',
                                    icon: Icons.inventory_rounded,
                                    keyboardType: TextInputType.number,
                                    required: true,
                                    colors: colors,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _formField(
                                    controller: minStockCtrl,
                                    label: 'Min Safe Stock',
                                    hint: '10',
                                    icon: Icons.warning_amber_rounded,
                                    keyboardType: TextInputType.number,
                                    colors: colors,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Section: Tax & Compliance
                          _sectionTitle('Tax & Compliance', colors),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _formField(
                                  controller: hsnCtrl,
                                  label: 'HSN Code',
                                  hint: '3004',
                                  icon: Icons.qr_code_rounded,
                                  colors: colors,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: [5, 12, 18].contains(gstSlab)
                                      ? gstSlab
                                      : 12,
                                  decoration: InputDecoration(
                                    labelText: 'GST Slab',
                                    prefixIcon: const Icon(
                                        Icons.percent_rounded,
                                        size: 18),
                                    filled: true,
                                    fillColor: colors.surfaceLight,
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 12),
                                  ),
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: colors.textPrimary),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 5, child: Text('5%')),
                                    DropdownMenuItem(
                                        value: 12, child: Text('12%')),
                                    DropdownMenuItem(
                                        value: 18, child: Text('18%')),
                                  ],
                                  onChanged: (v) =>
                                      setSheetState(() => gstSlab = v ?? 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _formField(
                                  controller: batchCtrl,
                                  label: 'Batch Number',
                                  hint: 'e.g. B2401',
                                  icon: Icons.numbers_rounded,
                                  colors: colors,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _formField(
                                  controller: rackCtrl,
                                  label: 'Rack / Shelf',
                                  hint: 'e.g. R2-S1',
                                  icon: Icons.shelves,
                                  colors: colors,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Prescription toggle
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  const Icon(Icons.medical_information_rounded,
                                      size: 18, color: AppColors.accent),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Prescription Required (Rx)',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              value: rxRequired,
                              activeThumbColor: AppColors.accent,
                              onChanged: (val) =>
                                  setSheetState(() => rxRequired = val),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Expiry date
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: expiryDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2040),
                              );
                              if (picked != null) {
                                setSheetState(() => expiryDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: colors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded,
                                      size: 18, color: colors.textSecondary),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Expiry Date',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd MMM yyyy')
                                            .format(expiryDate),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Icon(Icons.chevron_right_rounded,
                                      color: colors.textHint),
                                ],
                              ),
                            ),
                          ),
                          if (isEdit) ...[
                            const SizedBox(height: 14),
                            _formField(
                              controller: minStockCtrl,
                              label: 'Min Safe Stock Level',
                              hint: '10',
                              icon: Icons.warning_amber_rounded,
                              keyboardType: TextInputType.number,
                              colors: colors,
                            ),
                          ],
                          const SizedBox(height: 24),

                          // ─── Save Button ──────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }
                                      setSheetState(() => isSaving = true);

                                      final db =
                                          ref.read(databaseServiceProvider);
                                      if (db == null) {
                                        setSheetState(
                                            () => isSaving = false);
                                        return;
                                      }

                                      try {
                                        if (isEdit) {
                                          await db.updateMedicine(
                                              existing.id, {
                                            'name':
                                                nameCtrl.text.trim(),
                                            'genericName':
                                                genericCtrl.text.trim(),
                                            'category': selectedCat,
                                            'manufacturer':
                                                manufacturerCtrl.text
                                                    .trim(),
                                            'price':
                                                double.tryParse(
                                                        priceCtrl.text) ??
                                                    existing.price,
                                            'costPrice':
                                                double.tryParse(
                                                        costCtrl.text) ??
                                                    existing.costPrice,
                                            'hsn': hsnCtrl.text.trim().isNotEmpty
                                                ? hsnCtrl.text.trim()
                                                : '3004',
                                            'gstSlab': gstSlab,
                                            'batchNo':
                                                batchCtrl.text.trim(),
                                            'rackShelf':
                                                rackCtrl.text.trim(),
                                            'rxRequired': rxRequired,
                                            'reorderLevel':
                                                int.tryParse(minStockCtrl
                                                        .text) ??
                                                    existing.reorderLevel,
                                            'minStock':
                                                int.tryParse(minStockCtrl
                                                        .text) ??
                                                    existing.reorderLevel,
                                            'expiryDate': expiryDate,
                                          });
                                        } else {
                                          final medicine = Medicine(
                                            id: '',
                                            name: nameCtrl.text.trim(),
                                            genericName:
                                                genericCtrl.text.trim(),
                                            category: selectedCat,
                                            manufacturer:
                                                manufacturerCtrl.text
                                                    .trim(),
                                            price: double.parse(
                                                priceCtrl.text.trim()),
                                            costPrice:
                                                double.tryParse(
                                                        costCtrl.text
                                                            .trim()) ??
                                                    0,
                                            stock: int.parse(
                                                stockCtrl.text.trim()),
                                            reorderLevel: int.tryParse(
                                                    minStockCtrl.text
                                                        .trim()) ??
                                                10,
                                            hsn: hsnCtrl.text.trim().isNotEmpty
                                                ? hsnCtrl.text.trim()
                                                : '3004',
                                            gstSlab: gstSlab,
                                            batchNo:
                                                batchCtrl.text.trim(),
                                            rackShelf:
                                                rackCtrl.text.trim(),
                                            rxRequired: rxRequired,
                                            expiryDate: expiryDate,
                                          );
                                          await db
                                              .addMedicine(medicine);
                                        }

                                        if (sheetCtx.mounted) {
                                          Navigator.pop(sheetCtx);
                                        }
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(isEdit
                                                  ? '${nameCtrl.text.trim()} updated!'
                                                  : '${nameCtrl.text.trim()} added to inventory!'),
                                              backgroundColor:
                                                  AppColors.success,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setSheetState(
                                            () => isSaving = false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Failed to save: $e'),
                                              backgroundColor:
                                                  AppColors.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isEdit
                                          ? 'Save Changes'
                                          : 'Add to Inventory',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text, AppColors colors) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient:
                const LinearGradient(colors: AppColors.primaryGradient),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required AppColors colors,
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (keyboardType != null &&
                  keyboardType != TextInputType.text) {
                if (double.tryParse(v.trim()) == null) return 'Invalid';
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 12, color: colors.textHint),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
        prefixIcon: Icon(icon, size: 18, color: colors.textSecondary),
        filled: true,
        fillColor: colors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
