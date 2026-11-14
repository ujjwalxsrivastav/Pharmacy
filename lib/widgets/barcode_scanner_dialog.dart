import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

class BarcodeScannerDialog extends StatefulWidget {
  final ValueChanged<String> onBarcodeDetected;

  const BarcodeScannerDialog({super.key, required this.onBarcodeDetected});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BarcodeScannerDialog(
        onBarcodeDetected: (code) => Navigator.pop(ctx, code),
      ),
    );
  }

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _manualCtrl = TextEditingController();
  bool _hasDetected = false;

  @override
  void dispose() {
    _controller.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  void _handleCode(String rawCode) {
    if (_hasDetected) return;
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty) return;
    _hasDetected = true;
    widget.onBarcodeDetected(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.75,
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Medicine Barcode',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Point camera at medicine package barcode',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Camera Viewport
          Expanded(
            child: ClipRRect(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        final val = barcode.rawValue;
                        if (val != null && val.isNotEmpty) {
                          _handleCode(val);
                          break;
                        }
                      }
                    },
                  ),
                  // Reticle overlay
                  Container(
                    width: 240,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 2.5),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Manual Entry Fallback (essential for web, simulators, and barcode typing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCtrl,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Or enter barcode / batch / name manually...',
                      hintStyle: GoogleFonts.inter(fontSize: 12),
                      isDense: true,
                      prefixIcon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.surfaceLight),
                      ),
                    ),
                    onSubmitted: (v) => _handleCode(v),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _handleCode(_manualCtrl.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

