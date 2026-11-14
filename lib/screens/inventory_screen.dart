import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../services/database_service.dart';
import '../models/medicine.dart';
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
            final filtered = medicines.where((m) {
              return m.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  m.genericName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  m.category.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Inventory',
                              style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary)),
                          Text('Manage medicine catalog, stock levels & reorders',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: colors.textSecondary)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('${filtered.length} items',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    onChanged: (v) =>
                        ref.read(inventorySearchProvider.notifier).set(v),
                    style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'Search medicines by name, generic, category...',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Medicines List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 48, color: colors.textHint),
                              const SizedBox(height: 12),
                              Text('No medicines found',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textSecondary)),
                              const SizedBox(height: 4),
                              Text('Click + Add Medicine below to register items',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: colors.textHint)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _buildMedicineCard(
                              context, filtered[i], colors),
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
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddMedicineScreen())),
        icon: const Icon(Icons.add),
        label: Text('Add Medicine',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMedicineCard(
      BuildContext context, Medicine med, AppColors colors) {
    final isLow = med.isLowStock;
    final isExp = med.isExpired;
    final isExpSoon = med.isExpiringSoon;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExp
              ? AppColors.error.withValues(alpha: 0.4)
              : isLow
                  ? AppColors.warning.withValues(alpha: 0.4)
                  : Colors.transparent,
          width: 1,
        ),
      ),
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
                      med.name,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary),
                    ),
                    if (med.genericName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        med.genericName,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            med.category,
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isExp)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'EXPIRED',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error),
                            ),
                          )
                        else if (isExpSoon)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'EXP SOON',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${med.price.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isLow
                          ? AppColors.warning.withValues(alpha: 0.15)
                          : AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${med.stock} in stock',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isLow ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Actions Row: Stock In, Stock Out, Details / Edit
          Row(
            children: [
              // Stock In Button
              TextButton.icon(
                onPressed: () => _showStockAdjustmentDialog(
                    context, med, isStockIn: true),
                icon: const Icon(Icons.arrow_upward_rounded,
                    size: 16, color: AppColors.success),
                label: Text(
                  'Stock In',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: AppColors.success.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),

              // Stock Out Button
              TextButton.icon(
                onPressed: () => _showStockAdjustmentDialog(
                    context, med, isStockIn: false),
                icon: const Icon(Icons.arrow_downward_rounded,
                    size: 16, color: AppColors.warning),
                label: Text(
                  'Stock Out',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: AppColors.warning.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const Spacer(),

              // Details & Edit Button
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                color: colors.textSecondary,
                onPressed: () => _showMedicineDetail(context, med),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStockAdjustmentDialog(
      BuildContext context, Medicine med, {required bool isStockIn}) {
    final colors = AppColors.of(context);
    final qtyCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          isStockIn ? 'Stock In: ${med.name}' : 'Stock Out: ${med.name}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Stock: ${med.stock} units',
              style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              isStockIn
                  ? 'Quantity to Add:'
                  : 'Quantity to Remove:',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.inter(color: colors.textPrimary),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.numbers_rounded),
                hintText: 'Enter quantity',
              ),
            ),
            const SizedBox(height: 12),
            // Quick preset chips
            Row(
              children: [10, 25, 50, 100].map((q) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text('+$q', style: const TextStyle(fontSize: 11)),
                    onPressed: () => qtyCtrl.text = '$q',
                    backgroundColor: colors.surfaceLight,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              if (qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid quantity greater than 0')),
                );
                return;
              }

              if (!isStockIn) {
                if (med.stock < qty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Cannot perform Stock Out of $qty. Current stock is only ${med.stock}.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
              }

              Navigator.pop(dlgCtx);
              final db = ref.read(databaseServiceProvider);
              if (db != null) {
                final delta = isStockIn ? qty : -qty;
                await db.adjustStock(med.id, delta);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isStockIn
                          ? 'Stock for ${med.name} increased by $qty units.'
                          : 'Stock for ${med.name} decreased by $qty units.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isStockIn ? AppColors.success : AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: Text(isStockIn ? 'Add Stock' : 'Remove Stock',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showMedicineDetail(BuildContext context, Medicine med) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: colors.surfaceLight,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name,
                          style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                      if (med.genericName.isNotEmpty)
                        Text(med.genericName,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: colors.textSecondary)),
                    ],
                  ),
                ),
                Text('₹${med.price.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _detailRow('Category', med.category, colors),
            _detailRow('Manufacturer',
                med.manufacturer.isEmpty ? '—' : med.manufacturer, colors),
            _detailRow('Stock', '${med.stock} units', colors),
            _detailRow(
                'Min Safe Stock', '${med.reorderLevel} units', colors),
            _detailRow(
                'Cost Price', '₹${med.costPrice.toStringAsFixed(2)}', colors),
            _detailRow('Profit Margin',
                '${med.profitMargin.toStringAsFixed(1)}%', colors),
            _detailRow('Expiry Date',
                DateFormat('dd MMM yyyy').format(med.expiryDate), colors),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditMedicineDialog(context, med);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDelete(context, med);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditMedicineDialog(BuildContext context, Medicine med) {
    final colors = AppColors.of(context);
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: med.name);
    final genericCtrl = TextEditingController(text: med.genericName);
    final manufacturerCtrl = TextEditingController(text: med.manufacturer);
    final priceCtrl = TextEditingController(text: med.price.toString());
    final costCtrl = TextEditingController(text: med.costPrice.toString());
    final minStockCtrl = TextEditingController(text: med.reorderLevel.toString());
    String category = med.category;
    DateTime expiry = med.expiryDate;

    final categories = [
      'Pain Relief',
      'Antibiotics',
      'Allergy',
      'Diabetes',
      'Cardiovascular',
      'Gastrointestinal',
      'Vitamins',
      'Dermatology',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (dlgContext) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: colors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit medicine details',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Medicine Name *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: genericCtrl,
                    decoration: const InputDecoration(labelText: 'Generic Name'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: categories.contains(category) ? category : 'Other',
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setDlgState(() => category = v!),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: manufacturerCtrl,
                    decoration: const InputDecoration(labelText: 'Manufacturer'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Selling Price (₹)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Cost Price (₹)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: minStockCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Min Safe Stock Level'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expiry Date',
                        style: TextStyle(fontSize: 13)),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(expiry),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: expiry,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDlgState(() => expiry = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dlgContext);
                final db = ref.read(databaseServiceProvider);
                if (db != null) {
                  await db.updateMedicine(med.id, {
                    'name': nameCtrl.text.trim(),
                    'genericName': genericCtrl.text.trim(),
                    'category': category,
                    'manufacturer': manufacturerCtrl.text.trim(),
                    'price': double.tryParse(priceCtrl.text) ?? med.price,
                    'costPrice': double.tryParse(costCtrl.text) ?? med.costPrice,
                    'reorderLevel':
                        int.tryParse(minStockCtrl.text) ?? med.reorderLevel,
                    'minStock':
                        int.tryParse(minStockCtrl.text) ?? med.reorderLevel,
                    'expiryDate': expiry,
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Medicine updated successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Medicine med) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text(
            'Are you sure you want to permanently delete "${med.name}" from inventory? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
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
                      content: Text('Medicine deleted from inventory.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary)),
      ]),
    );
  }
}
