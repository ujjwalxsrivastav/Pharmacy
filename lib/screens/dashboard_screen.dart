import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../widgets/glass_stat_card.dart';
import '../widgets/sales_chart.dart';
import '../widgets/profile_bottom_sheet.dart';
import '../models/sale.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good Morning' : now.hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final dateStr = DateFormat('EEEE, d MMMM').format(now);

    final medicinesAsync = ref.watch(medicinesStreamProvider);
    final salesAsync = ref.watch(salesStreamProvider);
    final profileAsync = ref.watch(pharmacyProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: medicinesAsync.when(
          data: (medicines) {
            final lowStock = medicines.where((m) => m.isLowStock).length;
            final expiring = medicines.where((m) => m.isExpiringSoon || m.isExpired).length;

            return salesAsync.when(
              data: (sales) {
                final today = DateFormat('yyyy-MM-dd').format(now);
                final todaySales = sales.where((s) => DateFormat('yyyy-MM-dd').format(s.date) == today).toList();
                final todayRevenue = todaySales.fold<double>(0, (sum, s) => sum + s.totalPrice);
                final weeklyData = _calculateWeeklySales(sales);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text('$greeting 👋', style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary)),
                            const SizedBox(height: 4),
                            profileAsync.when(
                              data: (profile) {
                                final handler = (profile?.handlerName ?? '').isNotEmpty
                                    ? profile!.handlerName
                                    : 'Ujjwal';
                                final pharmacy = (profile?.pharmacyName ?? '').isNotEmpty
                                    ? profile!.pharmacyName
                                    : 'Test';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      handler,
                                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: colors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.local_pharmacy_rounded, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          pharmacy,
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                              loading: () => Text('Welcome', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                              error: (_, __) => Text('Welcome', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                            ),
                          ]),
                        ),
                        GestureDetector(
                          onTap: () => ref.read(themeModeProvider.notifier).toggle(),
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: colors.surfaceLight),
                            child: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: isDark ? AppColors.warning : AppColors.accent, size: 22),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final profile = profileAsync.valueOrNull;
                            showProfileBottomSheet(context, ref, profile);
                          },
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: AppColors.accentGradient)),
                            child: const Icon(Icons.person, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: GoogleFonts.inter(fontSize: 12, color: colors.textHint)),
                    const SizedBox(height: 20),

                    // Quick Action Banner
                    GestureDetector(
                      onTap: () => ref.read(selectedTabProvider.notifier).set(3),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: AppColors.primaryGradient),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Analytics & Reports', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text('View peak sales hours, top products & custom metrics', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Stats
                    GridView.count(
                      crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.15,
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      children: [
                        GestureDetector(
                          onTap: () => ref.read(selectedTabProvider.notifier).set(2),
                          child: GlassStatCard(title: "Today's Revenue", value: '₹${NumberFormat('#,##0').format(todayRevenue)}', subtitle: '${todaySales.length} orders today', icon: Icons.trending_up_rounded, gradient: AppColors.primaryGradient),
                        ),
                        GestureDetector(
                          onTap: () => ref.read(selectedTabProvider.notifier).set(1),
                          child: GlassStatCard(title: 'Total Products', value: '${medicines.length}', subtitle: 'In inventory', icon: Icons.shopping_bag_rounded, gradient: AppColors.coolGradient),
                        ),
                        GestureDetector(
                          onTap: () => ref.read(selectedTabProvider.notifier).set(4),
                          child: GlassStatCard(title: 'Low Stock Items', value: '$lowStock', subtitle: 'Needs reorder', icon: Icons.warning_amber_rounded, gradient: AppColors.warmGradient),
                        ),
                        GestureDetector(
                          onTap: () => ref.read(selectedTabProvider.notifier).set(4),
                          child: GlassStatCard(title: 'Expiring Soon', value: '$expiring', subtitle: 'Within 30 days', icon: Icons.timer_outlined, gradient: AppColors.accentGradient),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SalesChart(weeklyData: weeklyData),
                    const SizedBox(height: 20),

                    _sectionHeader('Recent Transactions', AppColors.accentGradient, colors),
                    const SizedBox(height: 10),
                    if (sales.isEmpty)
                      Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('No recent transactions', style: GoogleFonts.inter(color: colors.textSecondary)))),
                    ...sales.take(5).map((sale) => _activityTile(
                          sale.medicineName,
                          'Qty: ${sale.quantity}  •  ₹${sale.totalPrice}',
                          Icons.receipt_long_rounded,
                          AppColors.success,
                          _formatRelativeTime(sale.date),
                          colors,
                        )),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Error loading sales. Please ensure your Firestore database is created in the Firebase Console.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: colors.textSecondary)))),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Error loading inventory. Please ensure your Firestore database is created in the Firebase Console.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: colors.textSecondary)))),
        ),
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

  Widget _sectionHeader(String title, List<Color> gradientColors, AppColors colors) {
    return Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: gradientColors))),
      const SizedBox(width: 10),
      Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
    ]);
  }

  Widget _activityTile(String title, String subtitle, IconData icon, Color color, String time, AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.surfaceCard, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: color.withValues(alpha: 0.12)), child: Icon(icon, size: 20, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
        ])),
        Text(time, style: GoogleFonts.inter(fontSize: 10, color: colors.textHint)),
      ]),
    );
  }
}
