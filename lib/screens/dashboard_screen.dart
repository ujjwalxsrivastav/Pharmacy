import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../widgets/glass_stat_card.dart';
import '../widgets/sales_chart.dart';
import '../widgets/profile_bottom_sheet.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/bill_receipt_dialog.dart';
import '../models/sale.dart';
import 'orders_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final dateStr = DateFormat('EEEE, d MMMM').format(now);

    final medicinesAsync = ref.watch(medicinesStreamProvider);
    final salesAsync = ref.watch(salesStreamProvider);
    final profileAsync = ref.watch(pharmacyProfileProvider);
    final pendingOrders = ref.watch(pendingOrdersCountProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: medicinesAsync.when(
          data: (medicines) {
            final lowStockMedicines =
                medicines.where((m) => m.isLowStock && !m.isExpired).toList();
            final expiringMedicines =
                medicines.where((m) => m.isExpiringSoon || m.isExpired).toList();
            final lowStock = lowStockMedicines.length;
            final expiring = expiringMedicines.length;

            return salesAsync.when(
              data: (sales) {
                final today = DateFormat('yyyy-MM-dd').format(now);
                final todaySales = sales
                    .where((s) => DateFormat('yyyy-MM-dd').format(s.date) == today)
                    .toList();
                final todayRevenue =
                    todaySales.fold<double>(0, (sum, s) => sum + s.totalPrice);
                final weeklyData = _calculateWeeklySales(sales);
                final profile = profileAsync.valueOrNull;

                final handler = (profile?.handlerName ?? '').isNotEmpty
                    ? profile!.handlerName
                    : 'Ujjwal';
                final pharmacy = (profile?.pharmacyName ?? '').isNotEmpty
                    ? profile!.pharmacyName
                    : 'Klinixy Dehradun';

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1360),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth > 950;
                        final isTablet = constraints.maxWidth > 600;

                        return ListView(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 32 : 20,
                            20,
                            isDesktop ? 32 : 20,
                            32,
                          ),
                          children: [
                            // ─── Top Header & Pharmacist Bar ──────────────
                            _buildTopHeader(
                              context: context,
                              ref: ref,
                              colors: colors,
                              isDark: isDark,
                              greeting: greeting,
                              dateStr: dateStr,
                              handler: handler,
                              pharmacy: pharmacy,
                              profile: profile,
                              pendingOrders: pendingOrders,
                              isDesktop: isDesktop,
                            ),
                            const SizedBox(height: 18),

                            // ─── Location Callout (if not set) ────────────
                            if (profile != null && !profile.hasLocation) ...[
                              _buildLocationCallout(context, ref, colors, profile),
                              const SizedBox(height: 16),
                            ],

                            // ─── Quick Actions Hero Row ───────────────────
                            _buildActionHeroRow(
                              context: context,
                              ref: ref,
                              colors: colors,
                              isDesktop: isDesktop,
                              pendingOrders: pendingOrders,
                            ),
                            const SizedBox(height: 20),

                            // ─── 4 KPI Stat Cards (Responsive Grid) ───────
                            _buildKpiCardsGrid(
                              context: context,
                              ref: ref,
                              todayRevenue: todayRevenue,
                              todayOrdersCount: todaySales.length,
                              medicinesCount: medicines.length,
                              lowStock: lowStock,
                              expiring: expiring,
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                            ),
                            const SizedBox(height: 24),

                            // ─── Main Content Section ─────────────────────
                            if (isDesktop)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column: Weekly Chart + Recent Invoices
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SalesChart(weeklyData: weeklyData),
                                        const SizedBox(height: 24),
                                        _buildRecentTransactionsCard(
                                          context: context,
                                          ref: ref,
                                          colors: colors,
                                          sales: sales,
                                          profile: profile,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  // Right Column: Store Operational Hub + Inventory Watch
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildStoreHubCard(
                                          context: context,
                                          ref: ref,
                                          colors: colors,
                                          profile: profile,
                                        ),
                                        const SizedBox(height: 20),
                                        _buildInventoryWatchCard(
                                          context: context,
                                          ref: ref,
                                          colors: colors,
                                          lowStockMeds: lowStockMedicines,
                                          expiringMeds: expiringMedicines,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              // Mobile / Tablet Single Column
                              SalesChart(weeklyData: weeklyData),
                              const SizedBox(height: 20),
                              _buildStoreHubCard(
                                context: context,
                                ref: ref,
                                colors: colors,
                                profile: profile,
                              ),
                              const SizedBox(height: 20),
                              _buildInventoryWatchCard(
                                context: context,
                                ref: ref,
                                colors: colors,
                                lowStockMeds: lowStockMedicines,
                                expiringMeds: expiringMedicines,
                              ),
                              const SizedBox(height: 24),
                              _buildRecentTransactionsCard(
                                context: context,
                                ref: ref,
                                colors: colors,
                                sales: sales,
                                profile: profile,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
              loading: () => const DashboardSkeleton(),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Error loading sales: $err',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: colors.textSecondary),
                  ),
                ),
              ),
            );
          },
          loading: () => const DashboardSkeleton(),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Error loading inventory: $err',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: colors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Top Header Widget ──────────────────────────────────────────────────────
  Widget _buildTopHeader({
    required BuildContext context,
    required WidgetRef ref,
    required AppColors colors,
    required bool isDark,
    required String greeting,
    required String dateStr,
    required String handler,
    required String pharmacy,
    required dynamic profile,
    required int pendingOrders,
    required bool isDesktop,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '$greeting 👋',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (profile?.isOpen ?? true)
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (profile?.isOpen ?? true)
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (profile?.isOpen ?? true)
                              ? 'Open for Orders'
                              : 'Store Closed',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: (profile?.isOpen ?? true)
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      handler,
                      style: GoogleFonts.inter(
                        fontSize: isDesktop ? 26 : 22,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => showEditProfileDialog(context, ref, profile),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.surfaceLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_pharmacy_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            pharmacy,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            (profile?.hasLocation ?? false)
                                ? Icons.check_circle_rounded
                                : Icons.location_off_rounded,
                            size: 12,
                            color: (profile?.hasLocation ?? false)
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colors.textHint,
                ),
              ),
            ],
          ),
        ),

        // Action Buttons Row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick "+ New Bill" button on wide screens
            if (isDesktop) ...[
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(selectedTabProvider.notifier).set(2),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ New Bill'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
              const SizedBox(width: 10),
            ],

            // Orders Inbox with Badge
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrdersScreen()),
              ),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: pendingOrders > 0
                      ? AppColors.error.withValues(alpha: 0.15)
                      : colors.surfaceLight,
                  border: pendingOrders > 0
                      ? Border.all(
                          color: AppColors.error.withValues(alpha: 0.5))
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      color: pendingOrders > 0
                          ? AppColors.error
                          : colors.textPrimary,
                      size: 22,
                    ),
                    if (pendingOrders > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            '$pendingOrders',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Theme Toggle
            GestureDetector(
              onTap: () => ref.read(themeModeProvider.notifier).toggle(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: colors.surfaceLight,
                ),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? AppColors.warning : AppColors.accent,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Profile Avatar
            GestureDetector(
              onTap: () => showProfileBottomSheet(context, ref, profile),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                      colors: AppColors.accentGradient),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Location Callout Banner ────────────────────────────────────────────────
  Widget _buildLocationCallout(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    dynamic profile,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded,
              color: AppColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Your Pharmacy Location & GPS',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  'Quick-commerce delivery and customer discovery require your store GPS coordinates.',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => showEditProfileDialog(context, ref, profile),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Set GPS Now',
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dual Action Hero Row ───────────────────────────────────────────────────
  Widget _buildActionHeroRow({
    required BuildContext context,
    required WidgetRef ref,
    required AppColors colors,
    required bool isDesktop,
    required int pendingOrders,
  }) {
    if (isDesktop) {
      return Row(
        children: [
          // Banner 1: POS Walk-in Billing
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(selectedTabProvider.notifier).set(2),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.primaryGradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.point_of_sale_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Start Counter Billing',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Process walk-in prescriptions, barcode scan & thermal bills',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Banner 2: Analytics & Reports
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(selectedTabProvider.notifier).set(3),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.analytics_outlined,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Analytics & Reports',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'View peak sales hours, top products & custom metrics',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Mobile / Tablet Banner (Single Card Linking to Analytics / Billing)
    return GestureDetector(
      onTap: () => ref.read(selectedTabProvider.notifier).set(3),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.primaryGradient,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.analytics_outlined,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Analytics & Reports',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'View peak sales hours, top products & custom metrics →',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  // ─── 4 Responsive KPI Cards Grid ───────────────────────────────────────────
  Widget _buildKpiCardsGrid({
    required BuildContext context,
    required WidgetRef ref,
    required double todayRevenue,
    required int todayOrdersCount,
    required int medicinesCount,
    required int lowStock,
    required int expiring,
    required bool isDesktop,
    required bool isTablet,
  }) {
    final int crossAxisCount = isDesktop ? 4 : 2;
    final double childAspectRatio = isDesktop ? 1.75 : 1.85;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        GestureDetector(
          onTap: () => ref.read(selectedTabProvider.notifier).set(2),
          child: GlassStatCard(
            title: "Today's Revenue",
            value: '₹${NumberFormat('#,##0.00').format(todayRevenue)}',
            subtitle: '$todayOrdersCount orders today',
            icon: Icons.currency_rupee_rounded,
            gradient: AppColors.primaryGradient,
            badgeText: todayOrdersCount > 0 ? 'Active' : 'Live',
          ),
        ),
        GestureDetector(
          onTap: () => ref.read(selectedTabProvider.notifier).set(1),
          child: GlassStatCard(
            title: 'Total Products',
            value: '$medicinesCount',
            subtitle: 'In inventory',
            icon: Icons.inventory_2_rounded,
            gradient: AppColors.coolGradient,
            badgeText: 'Catalog',
          ),
        ),
        GestureDetector(
          onTap: () => ref.read(selectedTabProvider.notifier).set(4),
          child: GlassStatCard(
            title: 'Low Stock Items',
            value: '$lowStock',
            subtitle: 'Needs reorder',
            icon: Icons.warning_amber_rounded,
            gradient: AppColors.warmGradient,
            badgeText: lowStock > 0 ? 'Reorder' : 'Healthy',
          ),
        ),
        GestureDetector(
          onTap: () => ref.read(selectedTabProvider.notifier).set(4),
          child: GlassStatCard(
            title: 'Expiring Soon',
            value: '$expiring',
            subtitle: 'Within 30 days',
            icon: Icons.timer_outlined,
            gradient: AppColors.accentGradient,
            badgeText: expiring > 0 ? 'Alert' : 'Safe',
          ),
        ),
      ],
    );
  }

  // ─── Recent Transactions Card ───────────────────────────────────────────────
  Widget _buildRecentTransactionsCard({
    required BuildContext context,
    required WidgetRef ref,
    required AppColors colors,
    required List<Sale> sales,
    required dynamic profile,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.surfaceLight, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: AppColors.primaryGradient,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Recent Transactions',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () =>
                    ref.read(selectedTabProvider.notifier).set(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All Invoices',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sales.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 40, color: colors.textHint),
                    const SizedBox(height: 8),
                    Text(
                      'No recent transactions',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Process sales via Counter Billing to generate receipts.',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: colors.textHint),
                    ),
                  ],
                ),
              ),
            )
          else
            ...sales.take(6).map((sale) {
              final isPakka = sale.isPakka;
              final isRefund = sale.billType == 'refund';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceLight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => BillReceiptDialog(
                        sale: sale,
                        pharmacyName:
                            profile?.pharmacyName ?? 'Klinixy Pharmacy',
                        pharmacyAddress: profile != null
                            ? '${profile.area}, ${profile.city}'
                            : 'Dehradun, Selaqui',
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
                              : Icons.receipt_long_rounded,
                          size: 18,
                          color: isRefund
                              ? AppColors.error
                              : (isPakka
                                  ? AppColors.primary
                                  : AppColors.warning),
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isPakka
                                        ? AppColors.primary
                                            .withValues(alpha: 0.15)
                                        : AppColors.warning
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isPakka ? 'PAKKA' : 'KACCHA',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: isPakka
                                          ? AppColors.primary
                                          : AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${sale.medicineName} • ${sale.customerName}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${NumberFormat('#,##0.00').format(sale.totalPrice)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isRefund
                                  ? AppColors.error
                                  : colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatRelativeTime(sale.date),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: colors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── Store Operational Hub Card ─────────────────────────────────────────────
  Widget _buildStoreHubCard({
    required BuildContext context,
    required WidgetRef ref,
    required AppColors colors,
    required dynamic profile,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.surfaceLight, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Store Operations',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => showEditProfileDialog(context, ref, profile),
                child: Text(
                  'Edit Settings',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Store Open/Close Status Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  (profile?.isOpen ?? true)
                      ? Icons.storefront_rounded
                      : Icons.store_rounded,
                  color: (profile?.isOpen ?? true)
                      ? AppColors.success
                      : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (profile?.isOpen ?? true)
                            ? 'Store Open for Walk-ins & Delivery'
                            : 'Store Closed to Orders',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Delivery Radius: ${profile?.deliveryRadiusKm ?? 5.0} km',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Location details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.area != null && profile.area.isNotEmpty
                            ? '${profile.area}, ${profile.city}'
                            : 'Location Not Configured',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        profile?.hasLocation ?? false
                            ? 'GPS: ${profile.latitude?.toStringAsFixed(4)}, ${profile.longitude?.toStringAsFixed(4)}'
                            : 'Tap to configure store GPS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Inventory Attention Card ───────────────────────────────────────────────
  Widget _buildInventoryWatchCard({
    required BuildContext context,
    required WidgetRef ref,
    required AppColors colors,
    required List<dynamic> lowStockMeds,
    required List<dynamic> expiringMeds,
  }) {
    final hasAlerts = lowStockMeds.isNotEmpty || expiringMeds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.surfaceLight, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Inventory Health Watch',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => ref.read(selectedTabProvider.notifier).set(4),
                child: Text(
                  'Alerts Tab →',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasAlerts)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All stock levels healthy! No expired items.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (lowStockMeds.isNotEmpty) ...[
              Text(
                'Items Requiring Reorder:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 6),
              ...lowStockMeds.take(2).map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 14, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            m.name,
                            style: GoogleFonts.inter(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${m.stock} left (min: ${m.reorderLevel})',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            if (expiringMeds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Expiring / Expired Batches:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 6),
              ...expiringMeds.take(2).map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 14, color: AppColors.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            m.name,
                            style: GoogleFonts.inter(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          m.isExpired
                              ? 'EXPIRED'
                              : DateFormat('dd/MM/yy').format(m.expiryDate),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ],
      ),
    );
  }

  List<double> _calculateWeeklySales(List<Sale> sales) {
    final List<double> dailyTotals = List.filled(7, 0.0);
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonday = DateTime(monday.year, monday.month, monday.day);
    for (var sale in sales) {
      if (sale.date.isAfter(startOfMonday)) {
        final dayIndex = sale.date.weekday - 1;
        if (dayIndex >= 0 && dayIndex < 7) {
          dailyTotals[dayIndex] += sale.totalPrice;
        }
      }
    }
    return dailyTotals;
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
