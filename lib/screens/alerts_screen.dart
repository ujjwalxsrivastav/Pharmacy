import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final medicinesAsync = ref.watch(medicinesStreamProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text('Alerts', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            ),
            const SizedBox(height: 16),
            medicinesAsync.when(
              data: (medicines) {
                final expired = medicines.where((m) => m.isExpired).toList();
                final expiringSoon = medicines.where((m) => m.isExpiringSoon).toList();
                final lowStock = medicines.where((m) => m.isLowStock && !m.isExpired).toList();

                final allAlerts = [
                  ...expired.map((m) => _AlertItem(medicine: m, type: AlertType.expired)),
                  ...expiringSoon.map((m) => _AlertItem(medicine: m, type: AlertType.expiringSoon)),
                  ...lowStock.map((m) => _AlertItem(medicine: m, type: AlertType.lowStock)),
                ];

                if (allAlerts.isEmpty) {
                  return Expanded(
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success),
                        const SizedBox(height: 16),
                        Text('All Clear!', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                        const SizedBox(height: 8),
                        Text('No alerts at this time', style: GoogleFonts.inter(color: colors.textSecondary)),
                      ]),
                    ),
                  );
                }

                return Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allAlerts.length,
                    itemBuilder: (_, i) {
                      final alert = allAlerts[i];
                      final med = alert.medicine;
                      Color alertColor;
                      String alertTitle;
                      String alertSubtitle;
                      IconData alertIcon;

                      switch (alert.type) {
                        case AlertType.expired:
                          alertColor = AppColors.error;
                          alertIcon = Icons.dangerous_rounded;
                          alertTitle = 'EXPIRED: ${med.name}';
                          alertSubtitle = 'Expired on ${DateFormat('dd MMM yyyy').format(med.expiryDate)}';
                          break;
                        case AlertType.expiringSoon:
                          alertColor = AppColors.warning;
                          alertIcon = Icons.timer_rounded;
                          alertTitle = 'Expiring Soon: ${med.name}';
                          alertSubtitle = 'Expires on ${DateFormat('dd MMM yyyy').format(med.expiryDate)}';
                          break;
                        case AlertType.lowStock:
                          alertColor = AppColors.warning;
                          alertIcon = Icons.inventory_2_rounded;
                          alertTitle = 'Low Stock: ${med.name}';
                          alertSubtitle = 'Only ${med.stock} units left (reorder at ${med.reorderLevel})';
                          break;
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: alertColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: alertColor.withValues(alpha: 0.12)), child: Icon(alertIcon, color: alertColor, size: 22)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text(alertTitle, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(alertSubtitle, style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
                          ])),
                        ]),
                      );
                    },
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
}

enum AlertType { expired, expiringSoon, lowStock }

class _AlertItem {
  final dynamic medicine;
  final AlertType type;
  const _AlertItem({required this.medicine, required this.type});
}
