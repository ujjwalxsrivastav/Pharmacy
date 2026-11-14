import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../services/printer_service.dart';
import '../theme/app_theme.dart';

class BillReceiptDialog extends StatelessWidget {
  final Sale sale;
  final String pharmacyName;
  final String pharmacyAddress;
  final String? gstin;
  final String? phone;

  const BillReceiptDialog({
    super.key,
    required this.sale,
    this.pharmacyName = 'Klinixy Pharmacy',
    this.pharmacyAddress = 'Dehradun, Selaqui',
    this.gstin,
    this.phone,
  });

  static Future<void> show(
    BuildContext context, {
    required Sale sale,
    String? pharmacyName,
    String? pharmacyAddress,
    String? gstin,
    String? phone,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BillReceiptDialog(
        sale: sale,
        pharmacyName: pharmacyName ?? 'Klinixy Pharmacy',
        pharmacyAddress: pharmacyAddress ?? 'Dehradun, Selaqui',
        gstin: gstin,
        phone: phone,
      ),
    );
  }

  static Future<void> printDocument(
    BuildContext context, {
    required Sale sale,
    String? pharmacyName,
    String? pharmacyAddress,
    String? gstin,
    String? phone,
  }) async {
    try {
      await PrinterService.printReceipt(
        sale: sale,
        pharmacyName: pharmacyName ?? 'Klinixy Pharmacy',
        pharmacyAddress: pharmacyAddress ?? 'Dehradun, Selaqui',
        gstin: gstin,
        phone: phone,
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
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(sale.date);

    return Dialog(
      backgroundColor: colors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: AppColors.primaryGradient),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.local_pharmacy_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      pharmacyName.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pharmacyAddress,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sale.isPakka
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sale.isPakka
                            ? 'OFFICIAL TAX INVOICE'
                            : 'ESTIMATE / KACCHA BILL',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: sale.isPakka
                              ? AppColors.primary
                              : AppColors.warning,
                        ),
                      ),
                    ),
                    if (sale.isPakka && (gstin?.trim().isNotEmpty ?? false)) ...[
                      const SizedBox(height: 4),
                      Text(
                        'GSTIN: ${gstin!.trim()}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: colors.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(thickness: 1),
              const SizedBox(height: 8),

              // Metadata
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bill No: #${sale.billNo}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary)),
                  Text(dateStr,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: colors.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Customer: ${sale.customerName}',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: colors.textSecondary)),
                  Text(sale.isPakka ? 'Pakka (+GST)' : 'Kaccha Bill',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary)),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(thickness: 1),
              const SizedBox(height: 8),

              // Items Header
              Row(
                children: [
                  Expanded(
                      flex: 5,
                      child: Text('Item',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary))),
                  Expanded(
                      flex: 2,
                      child: Text('Qty',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary))),
                  Expanded(
                      flex: 2,
                      child: Text('Rate',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary))),
                  Expanded(
                      flex: 3,
                      child: Text('Total',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary))),
                ],
              ),
              const SizedBox(height: 6),

              // Items List
              ...sale.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          item.medicineName,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${item.quantity}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: colors.textPrimary),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₹${item.unitPrice.toStringAsFixed(1)}',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: colors.textSecondary),
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
                              color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),
              const Divider(thickness: 1),
              const SizedBox(height: 8),

              // Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal:',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: colors.textSecondary)),
                  Text('₹${sale.subtotal.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary)),
                ],
              ),
              if (sale.isPakka) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('GST (18%):',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: colors.textSecondary)),
                    Text('₹${sale.taxAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Grand Total:',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary)),
                  Text('₹${sale.totalPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ],
              ),

              const SizedBox(height: 18),
              Center(
                child: Column(
                  children: [
                    Text('Get well soon! 💊',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: colors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('This is a computer generated bill.',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: colors.textHint)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await BillReceiptDialog.printDocument(
                          context,
                          sale: sale,
                          pharmacyName: pharmacyName,
                          pharmacyAddress: pharmacyAddress,
                          gstin: gstin,
                          phone: phone,
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
