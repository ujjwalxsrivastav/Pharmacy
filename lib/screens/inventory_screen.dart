import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../services/database_service.dart';
import '../models/medicine.dart';
import '../widgets/medicine_tile.dart';
import 'add_medicine_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final medicinesAsync = ref.watch(medicinesStreamProvider);
    final searchQuery = ref.watch(inventorySearchProvider);

    return Scaffold(
      body: SafeArea(
        child: medicinesAsync.when(
          data: (medicines) {
            var filtered = medicines.where((m) {
              return m.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                     m.genericName.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(children: [
                    Text('Inventory', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text('${filtered.length} items', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    onChanged: (v) => ref.read(inventorySearchProvider.notifier).set(v),
                    style: GoogleFonts.inter(color: colors.textPrimary),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search medicines...'),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text('No medicines found', style: GoogleFonts.inter(color: colors.textSecondary)))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => MedicineTile(
                            medicine: filtered[i],
                            onTap: () => _showMedicineDetail(context, filtered[i]),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMedicineScreen())),
        icon: const Icon(Icons.add),
        label: Text('Add Medicine', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showMedicineDetail(BuildContext context, Medicine med) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.surfaceLight, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(med.name, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: colors.textPrimary)),
          if (med.genericName.isNotEmpty) Text(med.genericName, style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary)),
          const SizedBox(height: 16),
          _detailRow('Category', med.category, colors),
          _detailRow('Manufacturer', med.manufacturer.isEmpty ? '—' : med.manufacturer, colors),
          _detailRow('Stock', '${med.stock} units', colors),
          _detailRow('Reorder Level', '${med.reorderLevel} units', colors),
          _detailRow('Selling Price', '₹${med.price.toStringAsFixed(2)}', colors),
          _detailRow('Cost Price', '₹${med.costPrice.toStringAsFixed(2)}', colors),
          _detailRow('Profit Margin', '${med.profitMargin.toStringAsFixed(1)}%', colors),
          _detailRow('Expiry Date', DateFormat('dd MMM yyyy').format(med.expiryDate), colors),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.edit), label: const Text('Edit'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final db = ref.read(databaseServiceProvider);
                if (db != null) {
                  await db.deleteMedicine(med.id);
                }
              },
              icon: const Icon(Icons.delete_outline), label: const Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            )),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
      ]),
    );
  }
}
