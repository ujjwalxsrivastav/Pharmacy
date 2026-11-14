import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../models/medicine.dart';
import '../models/sale.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/bill_receipt_dialog.dart';

class CounterBillingScreen extends ConsumerStatefulWidget {
  const CounterBillingScreen({super.key});

  @override
  ConsumerState<CounterBillingScreen> createState() => _CounterBillingScreenState();
}

class _CounterBillingScreenState extends ConsumerState<CounterBillingScreen> {
  final Map<String, int> _cart = {};
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _customerCtrl = TextEditingController();
  String _searchQuery = '';
  String _billType = 'pakka'; // 'pakka' or 'kaccha'
  bool _isProcessing = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final medicinesAsync = ref.watch(medicinesStreamProvider);
    final profile = ref.watch(pharmacyProfileProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: medicinesAsync.when(
          data: (medicines) {
            final cartItems = _cart.entries
                .where((e) => medicines.any((m) => m.id == e.key))
                .map((e) {
              final med = medicines.firstWhere((m) => m.id == e.key);
              return {'med': med, 'qty': e.value};
            }).toList();

            final subtotal = cartItems.fold<double>(0, (sum, item) {
              final med = item['med'] as Medicine;
              return sum + (med.price * (item['qty'] as int));
            });

            final gstAmount = _billType == 'pakka'
                ? cartItems.fold<double>(0, (sum, item) {
                    final med = item['med'] as Medicine;
                    final qty = item['qty'] as int;
                    return sum + ((med.price * qty) * (med.gstSlab / 100.0));
                  })
                : 0.0;
            final grandTotal = subtotal + gstAmount;

            final searchResults = _searchQuery.isEmpty
                ? <Medicine>[]
                : medicines
                    .where((m) =>
                        m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        m.genericName.toLowerCase().contains(_searchQuery.toLowerCase()))
                    .take(6)
                    .toList();

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
                          Text('Billing System',
                              style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary)),
                          Text('Quick walk-in pos & instant receipt generator',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: colors.textSecondary)),
                        ],
                      ),
                      const Spacer(),
                      if (cartItems.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('${cartItems.length} items',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Bill Type Selector & Customer Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Pakka Bill Chip
                      ChoiceChip(
                        label: const Text('Pakka Bill (+GST)'),
                        selected: _billType == 'pakka',
                        onSelected: (sel) {
                          if (sel) setState(() => _billType = 'pakka');
                        },
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _billType == 'pakka'
                              ? AppColors.primary
                              : colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Kaccha Bill Chip
                      ChoiceChip(
                        label: const Text('Kaccha Bill'),
                        selected: _billType == 'kaccha',
                        onSelected: (sel) {
                          if (sel) setState(() => _billType = 'kaccha');
                        },
                        selectedColor: AppColors.warning.withValues(alpha: 0.2),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _billType == 'kaccha'
                              ? AppColors.warning
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Customer Name input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _customerCtrl,
                    style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                      hintText: 'Customer Name (optional)',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Medicine Search input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'Search medicines to add...',
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // Search Results Dropdown List
                if (searchResults.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: searchResults.map((med) {
                        return ListTile(
                          dense: true,
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(med.name,
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: med.isExpired
                                            ? AppColors.error
                                            : colors.textPrimary)),
                              ),
                              if (med.rxRequired)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Rx Req',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accent)),
                                ),
                            ],
                          ),
                          subtitle: Text(
                              med.isExpired
                                  ? 'EXPIRED (${DateFormat('dd/MM/yy').format(med.expiryDate)}) — CANNOT DISPENSE'
                                  : '₹${med.price.toStringAsFixed(2)} • Stock: ${med.stock}${med.batchNo.isNotEmpty ? " • Batch: ${med.batchNo}" : ""}',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: med.isExpired
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: med.isExpired
                                      ? AppColors.error
                                      : colors.textSecondary)),
                          trailing: IconButton(
                            icon: Icon(
                                med.isExpired
                                    ? Icons.block
                                    : Icons.add_circle,
                                color: med.isExpired
                                    ? AppColors.error
                                    : AppColors.primary),
                            onPressed: (med.stock <= 0 || med.isExpired)
                                ? () {
                                    if (med.isExpired) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              '${med.name} expired on ${DateFormat('dd MMM yyyy').format(med.expiryDate)}! Expired medicines cannot be dispensed.'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                : () {
                                    // FEFO Warning: check if an earlier expiring batch is available
                                    final earlierBatch = medicines
                                        .where((m) =>
                                            m.id != med.id &&
                                            m.stock > 0 &&
                                            !m.isExpired &&
                                            (m.name.toLowerCase() ==
                                                    med.name.toLowerCase() ||
                                                (m.genericName.isNotEmpty &&
                                                    m.genericName
                                                            .toLowerCase() ==
                                                        med.genericName
                                                            .toLowerCase())) &&
                                            m.expiryDate
                                                .isBefore(med.expiryDate))
                                        .firstOrNull;

                                    if (earlierBatch != null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'FEFO Warning: Earlier expiring batch of ${earlierBatch.name} (Exp: ${DateFormat('dd/MM/yy').format(earlierBatch.expiryDate)}) exists!'),
                                          backgroundColor: AppColors.warning,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    }

                                    if (med.rxRequired) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Schedule H/H1 Warning: ${med.name} requires a doctor prescription.'),
                                          backgroundColor: AppColors.accent,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }

                                    final current = _cart[med.id] ?? 0;
                                    if (current < med.stock) {
                                      setState(() {
                                        _cart[med.id] = current + 1;
                                        _searchCtrl.clear();
                                        _searchQuery = '';
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Not enough stock! Only ${med.stock} left.')),
                                      );
                                    }
                                  },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // Cart Items Section
                Expanded(
                  child: cartItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.point_of_sale_outlined,
                                  size: 48, color: colors.textHint),
                              const SizedBox(height: 12),
                              Text('No medicines in cart',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textSecondary)),
                              const SizedBox(height: 4),
                              Text('Search and add medicines above to bill',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: colors.textHint)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: cartItems.length,
                          itemBuilder: (_, i) {
                            final med = cartItems[i]['med'] as Medicine;
                            final qty = cartItems[i]['qty'] as int;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.surfaceCard,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(med.name,
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                color: colors.textPrimary)),
                                        const SizedBox(height: 2),
                                        Text(
                                            '₹${med.price.toStringAsFixed(2)} each',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: colors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 20),
                                        onPressed: () => setState(() {
                                          qty > 1
                                              ? _cart[med.id] = qty - 1
                                              : _cart.remove(med.id);
                                        }),
                                      ),
                                      Text('$qty',
                                          style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w700,
                                              color: colors.textPrimary)),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 20),
                                        onPressed: () {
                                          if (qty < med.stock) {
                                            setState(() => _cart[med.id] = qty + 1);
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Not enough stock for ${med.name}')),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${(med.price * qty).toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Checkout Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  decoration: BoxDecoration(
                    color: colors.surfaceCard,
                    border: Border(top: BorderSide(color: colors.surfaceLight)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal:',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: colors.textSecondary)),
                          Text('₹${subtotal.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary)),
                        ],
                      ),
                      if (_billType == 'pakka') ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('CGST (intra-state):',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: colors.textSecondary)),
                            Text('₹${(gstAmount / 2).toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('SGST (intra-state):',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: colors.textSecondary)),
                            Text('₹${(gstAmount / 2).toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Tax (by slab):',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: colors.textSecondary)),
                            Text('₹${gstAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Total Amount',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: colors.textSecondary)),
                              Text('₹${grandTotal.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary)),
                            ],
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: (cartItems.isEmpty || _isProcessing)
                                ? null
                                : () async {
                                    final db = ref.read(databaseServiceProvider);
                                    if (db == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Database session not available.')),
                                      );
                                      return;
                                    }

                                    setState(() => _isProcessing = true);
                                    try {
                                      final saleItems = cartItems.map((item) {
                                        final med = item['med'] as Medicine;
                                        final qty = item['qty'] as int;
                                        final itemTotal = med.price * qty;
                                        final itemTax = _billType == 'pakka'
                                            ? (itemTotal * (med.gstSlab / 100.0))
                                            : 0.0;
                                        return SaleItem(
                                          medicineId: med.id,
                                          medicineName: med.name,
                                          quantity: qty,
                                          unitPrice: med.price,
                                          totalPrice: itemTotal,
                                          hsn: med.hsn,
                                          gstSlab: med.gstSlab,
                                          taxAmount: itemTax,
                                        );
                                      }).toList();

                                      final custName =
                                          _customerCtrl.text.trim().isNotEmpty
                                              ? _customerCtrl.text.trim()
                                              : 'Walk-in';

                                      final authUser = ref.read(authServiceProvider).currentUser;

                                      // Process sale & decrement stock atomically in one transaction
                                      final completedSale = await db.processAtomicSale(
                                        items: saleItems,
                                        customerName: custName,
                                        customerPhone: '',
                                        billType: _billType,
                                        subtotal: subtotal,
                                        taxAmount: gstAmount,
                                        totalPrice: grandTotal,
                                        updatedByUid: authUser?.uid,
                                      );

                                      if (mounted) {
                                        setState(() {
                                          _cart.clear();
                                          _customerCtrl.clear();
                                        });

                                        // Show Instant Thermal Receipt Dialog
                                        await BillReceiptDialog.show(
                                          context,
                                          sale: completedSale,
                                          pharmacyName: profile?.pharmacyName ??
                                              'Klinixy Pharmacy',
                                          pharmacyAddress: profile != null
                                              ? '${profile.area}, ${profile.city}'
                                              : 'Dehradun, Selaqui',
                                          gstin: profile?.gstin,
                                          phone: profile?.phone,
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Failed to process sale: $e')),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isProcessing = false);
                                      }
                                    }
                                  },
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.receipt_long_rounded,
                                    size: 18),
                            label: Text(
                              _billType == 'pakka'
                                  ? 'Generate Pakka Bill'
                                  : 'Generate Kaccha Bill',
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              backgroundColor: _billType == 'pakka'
                                  ? AppColors.primary
                                  : AppColors.warning,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}
