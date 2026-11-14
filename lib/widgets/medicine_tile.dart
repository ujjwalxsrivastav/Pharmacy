import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../theme/app_theme.dart';

class MedicineTile extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const MedicineTile({
    super.key,
    required this.medicine,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final expiryStr = DateFormat('dd MMM yyyy').format(medicine.expiryDate);

    Color statusColor;
    if (medicine.isExpired) {
      statusColor = AppColors.error;
    } else if (medicine.isExpiringSoon) {
      statusColor = AppColors.warning;
    } else if (medicine.isLowStock) {
      statusColor = AppColors.warning;
    } else {
      statusColor = AppColors.success;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: medicine.isLowStock || medicine.isExpired || medicine.isExpiringSoon
                ? statusColor.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: statusColor.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.medication_rounded, color: statusColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(medicine.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${medicine.category}  •  ${medicine.gstSlab}% GST  •  Exp: $expiryStr', style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('₹${medicine.price.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('Qty: ${medicine.stock}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
