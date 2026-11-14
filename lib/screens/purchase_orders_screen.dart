import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/purchase_order.dart';
import '../models/supplier.dart';
import '../providers/providers.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() =>
      _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final poAsync = ref.watch(purchaseOrdersStreamProvider);
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    final medicinesAsync = ref.watch(medicinesStreamProvider);
    final db = ref.watch(databaseServiceProvider);
    final authUser = ref.watch(authUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Purchase Orders & Suppliers',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: colors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Purchase Orders', icon: Icon(Icons.receipt_long_outlined)),
            Tab(text: 'Suppliers Directory', icon: Icon(Icons.business_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Purchase Orders
          _buildPurchaseOrdersTab(
            context,
            colors,
            poAsync,
            suppliersAsync.valueOrNull ?? [],
            medicinesAsync.valueOrNull ?? [],
            db,
            authUser?.uid ?? '',
          ),
          // Tab 2: Suppliers
          _buildSuppliersTab(
            context,
            colors,
            suppliersAsync,
            db,
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseOrdersTab(
    BuildContext context,
    AppColors colors,
    AsyncValue<List<PurchaseOrder>> poAsync,
    List<Supplier> suppliers,
    List<Medicine> medicines,
    DatabaseService? db,
    String uid,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePODialog(
          context,
          suppliers,
          medicines,
          db,
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Create PO',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: poAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_outlined,
                      size: 54, color: colors.textHint),
                  const SizedBox(height: 12),
                  Text(
                    'No Purchase Orders Created',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap "+ Create PO" to procure medicine batches from suppliers.',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final po = orders[index];
              final dateStr =
                  DateFormat('dd MMM yyyy, hh:mm a').format(po.createdAt);

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.surfaceLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              po.poNumber,
                              style: GoogleFonts.robotoMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              'Supplier: ${po.supplierName}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: po.isReceived
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            po.isReceived ? 'RECEIVED' : 'PENDING RECEIPT',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: po.isReceived
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Created: $dateStr',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: colors.textHint),
                    ),
                    const Divider(height: 16),
                    ...po.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.medicineName} (Batch: ${item.batchNo.isNotEmpty ? item.batchNo : "N/A"})',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: colors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${item.quantity} units @ ₹${item.unitCost.toStringAsFixed(1)} = ₹${item.totalCost.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total PO Amount:',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary),
                        ),
                        Text(
                          '₹${po.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (!po.isReceived) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (db == null) return;
                          try {
                            await db.receivePurchaseOrder(
                                poId: po.id, byUid: uid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Stock received and inventory updated atomically!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error receiving PO: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: const Text('Receive Stock & Update Batches'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSuppliersTab(
    BuildContext context,
    AppColors colors,
    AsyncValue<List<Supplier>> suppliersAsync,
    DatabaseService? db,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSupplierDialog(context, db),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: Text('Add Supplier',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business_center_outlined,
                      size: 54, color: colors.textHint),
                  const SizedBox(height: 12),
                  Text(
                    'No Suppliers Registered',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap "+ Add Supplier" to register distributors and pharmaceutical vendors.',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final sup = suppliers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.surfaceLight),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.business,
                          color: AppColors.accent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sup.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (sup.phone.isNotEmpty)
                            Text(
                              'Phone: ${sup.phone}',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: colors.textSecondary),
                            ),
                          if (sup.gstin.isNotEmpty)
                            Text(
                              'GSTIN: ${sup.gstin}',
                              style: GoogleFonts.robotoMono(
                                  fontSize: 11, color: colors.textHint),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddSupplierDialog(BuildContext context, DatabaseService? db) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final gstinCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Vendor / Supplier',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Supplier Name *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: gstinCtrl,
                  decoration: const InputDecoration(labelText: 'GSTIN Number'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: addressCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Physical Address'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate() || db == null) return;
              Navigator.pop(ctx);
              await db.addSupplier(
                Supplier(
                  id: '',
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  gstin: gstinCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                ),
              );
            },
            child: const Text('Save Supplier'),
          ),
        ],
      ),
    );
  }

  void _showCreatePODialog(
    BuildContext context,
    List<Supplier> suppliers,
    List<Medicine> medicines,
    DatabaseService? db,
  ) {
    if (medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please register medicines in inventory first!')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    String supplierId = suppliers.isNotEmpty ? suppliers.first.id : 'custom';
    String supplierName =
        suppliers.isNotEmpty ? suppliers.first.name : 'Direct Distributor';
    String selectedMedId = medicines.first.id;
    final batchCtrl = TextEditingController(text: 'B${DateTime.now().year}01');
    final qtyCtrl = TextEditingController(text: '100');
    final costCtrl = TextEditingController(
        text: medicines.first.costPrice > 0
            ? medicines.first.costPrice.toStringAsFixed(1)
            : (medicines.first.price * 0.7).toStringAsFixed(1));
    DateTime expiry = DateTime.now().add(const Duration(days: 730));

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Create Purchase Order',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (suppliers.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: supplierId,
                      decoration:
                          const InputDecoration(labelText: 'Supplier *'),
                      items: suppliers
                          .map((s) => DropdownMenuItem(
                              value: s.id, child: Text(s.name)))
                          .toList(),
                      onChanged: (v) {
                        setDlgState(() {
                          supplierId = v!;
                          supplierName =
                              suppliers.firstWhere((s) => s.id == v).name;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: selectedMedId,
                    decoration: const InputDecoration(labelText: 'Medicine *'),
                    items: medicines
                        .map((m) =>
                            DropdownMenuItem(value: m.id, child: Text(m.name)))
                        .toList(),
                    onChanged: (v) {
                      setDlgState(() {
                        selectedMedId = v!;
                        final m = medicines.firstWhere((med) => med.id == v);
                        if (m.costPrice > 0) {
                          costCtrl.text = m.costPrice.toStringAsFixed(1);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: batchCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Batch Number *'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Quantity *'),
                          validator: (v) =>
                              v == null || int.tryParse(v.trim()) == null
                                  ? 'Valid qty'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: costCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Unit Cost Price (₹) *'),
                    validator: (v) =>
                        v == null || double.tryParse(v.trim()) == null
                            ? 'Valid cost'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Batch Expiry Date',
                        style: TextStyle(fontSize: 12)),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(expiry),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: expiry,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
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
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate() || db == null) return;
                Navigator.pop(dlgCtx);

                final med =
                    medicines.firstWhere((m) => m.id == selectedMedId);
                final qty = int.parse(qtyCtrl.text.trim());
                final unitCost = double.parse(costCtrl.text.trim());
                final poNumber =
                    'PO-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

                final item = PurchaseOrderItem(
                  medicineId: med.id,
                  medicineName: med.name,
                  batchNo: batchCtrl.text.trim(),
                  expiryDate: expiry,
                  quantity: qty,
                  unitCost: unitCost,
                  totalCost: qty * unitCost,
                );

                final po = PurchaseOrder(
                  id: '',
                  poNumber: poNumber,
                  supplierId: supplierId,
                  supplierName: supplierName,
                  items: [item],
                  totalAmount: item.totalCost,
                  status: 'created',
                );

                await db.createPurchaseOrder(po);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('PO $poNumber created successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Save & Issue PO'),
            ),
          ],
        ),
      ),
    );
  }
}
