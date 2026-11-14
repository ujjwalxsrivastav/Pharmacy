import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sale.dart';

/// Real PDF generation and thermal receipt printing service for Klinixy Pharmacy.
/// Uses package:printing and package:pdf with zero fake notifications.
class PrinterService {
  PrinterService._();

  /// Generate 80mm roll thermal receipt PDF bytes.
  static Future<Uint8List> generateReceiptBytes({
    required Sale sale,
    required String pharmacyName,
    required String pharmacyAddress,
    String? gstin,
    String? phone,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(sale.date);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Store Header
              pw.Center(
                child: pw.Text(
                  pharmacyName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (pharmacyAddress.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    pharmacyAddress,
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
              if (phone != null && phone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'Phone: $phone',
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
              if (sale.isPakka && gstin != null && gstin.trim().isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'GSTIN: $gstin',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.5),
                  ),
                  child: pw.Text(
                    sale.isPakka
                        ? 'OFFICIAL TAX INVOICE'
                        : 'ESTIMATE / KACCHA BILL',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),
              // Bill Metadata
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill No: #${sale.billNo}',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateStr, style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer: ${sale.customerName}',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(sale.isPakka ? 'Tax Invoice' : 'Estimate',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              // Items Table Header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('Item',
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Qty',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Rate',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('Total',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),
              // Items
              ...sale.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Text(item.medicineName,
                            style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('${item.quantity}',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                            'Rs. ${item.unitPrice.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                            'Rs. ${item.totalPrice.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 0.5),
              // Subtotal & Tax Breakdown
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Rs. ${sale.subtotal.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (sale.isPakka) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CGST (9%):',
                        style: const pw.TextStyle(fontSize: 7)),
                    pw.Text('Rs. ${(sale.taxAmount / 2).toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SGST (9%):',
                        style: const pw.TextStyle(fontSize: 7)),
                    pw.Text('Rs. ${(sale.taxAmount / 2).toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Tax (18%):',
                        style: const pw.TextStyle(fontSize: 7)),
                    pw.Text('Rs. ${sale.taxAmount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Grand Total:',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rs. ${sale.totalPrice.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 0.8),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('Get well soon! 💊',
                    style: pw.TextStyle(
                        fontSize: 8, fontStyle: pw.FontStyle.italic)),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text('This is a computer generated invoice.',
                    style: const pw.TextStyle(
                        fontSize: 6, color: PdfColors.grey700)),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print or show print preview for receipt via system printing
  static Future<bool> printReceipt({
    required Sale sale,
    required String pharmacyName,
    required String pharmacyAddress,
    String? gstin,
    String? phone,
  }) async {
    final pdfBytes = await generateReceiptBytes(
      sale: sale,
      pharmacyName: pharmacyName,
      pharmacyAddress: pharmacyAddress,
      gstin: gstin,
      phone: phone,
    );

    return Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${sale.billNo}',
      format: PdfPageFormat.roll80,
    );
  }

  /// Generate A4 Financial & Sales Report PDF bytes
  static Future<Uint8List> generateSalesReportBytes({
    required List<Sale> sales,
    required String rangeLabel,
    required String pharmacyName,
    required String pharmacyAddress,
    String? gstin,
  }) async {
    final pdf = pw.Document();
    final totalRev = sales.fold<double>(0, (sum, s) => sum + s.totalPrice);
    final totalTax = sales.fold<double>(0, (sum, s) => sum + s.taxAmount);
    final pakkaCount = sales.where((s) => s.isPakka).length;
    final kacchaCount = sales.where((s) => !s.isPakka).length;
    final generatedAt =
        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        pharmacyName.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      if (pharmacyAddress.isNotEmpty)
                        pw.Text(pharmacyAddress,
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey700)),
                      if (gstin != null && gstin.isNotEmpty)
                        pw.Text('GSTIN: $gstin',
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FINANCIAL & SALES REPORT',
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal)),
                      pw.Text('Period: $rangeLabel',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Generated: $generatedAt',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.teal),
              pw.SizedBox(height: 8),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // KPI Summary table
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _summaryCell(
                      'Total Revenue', 'Rs. ${totalRev.toStringAsFixed(2)}'),
                  _summaryCell(
                      'GST Collected', 'Rs. ${totalTax.toStringAsFixed(2)}'),
                  _summaryCell('Transactions',
                      '${sales.length} ($pakkaCount Pakka, $kacchaCount Kaccha)'),
                  _summaryCell(
                      'Avg Value',
                      sales.isEmpty
                          ? 'Rs. 0.00'
                          : 'Rs. ${(totalRev / sales.length).toStringAsFixed(2)}'),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Detailed Transactions',
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            // Table
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              headers: [
                'Bill #',
                'Date & Time',
                'Customer',
                'Type',
                'Items',
                'Subtotal',
                'Tax',
                'Total'
              ],
              data: sales.map((s) {
                final dt = DateFormat('dd/MM/yy HH:mm').format(s.date);
                return [
                  '#${s.billNo}',
                  dt,
                  s.customerName,
                  s.isPakka ? 'Pakka' : 'Kaccha',
                  '${s.items.length}',
                  'Rs. ${s.subtotal.toStringAsFixed(2)}',
                  'Rs. ${s.taxAmount.toStringAsFixed(2)}',
                  'Rs. ${s.totalPrice.toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _summaryCell(String title, String value) {
    return pw.Column(
      children: [
        pw.Text(title,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  /// Print or export sales report
  static Future<bool> printSalesReport({
    required List<Sale> sales,
    required String rangeLabel,
    required String pharmacyName,
    required String pharmacyAddress,
    String? gstin,
  }) async {
    final pdfBytes = await generateSalesReportBytes(
      sales: sales,
      rangeLabel: rangeLabel,
      pharmacyName: pharmacyName,
      pharmacyAddress: pharmacyAddress,
      gstin: gstin,
    );

    return Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'SalesReport_${rangeLabel.replaceAll(' ', '_')}',
      format: PdfPageFormat.a4,
    );
  }
}
