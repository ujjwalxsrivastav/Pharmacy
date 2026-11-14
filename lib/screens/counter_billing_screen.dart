import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/barcode_scanner_dialog.dart';

class CounterBillingScreen extends ConsumerStatefulWidget {
  const CounterBillingScreen({super.key});

  @override
  ConsumerState<CounterBillingScreen> createState() =>
      _CounterBillingScreenState();
}

class _CounterBillingScreenState extends ConsumerState<CounterBillingScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _customerCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _billType = 'pakka'; // 'pakka' or 'kaccha'
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Keyboard-first autofocus on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customerCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _searchQuery = '');
    _searchFocusNode.requestFocus();
  }

  // Barcode Scan Handler
  Future<void> _startBarcodeScan(List<Medicine> medicines) async {
    final scannedCode = await BarcodeScannerDialog.show(context);
    if (scannedCode == null || scannedCode.isEmpty || !mounted) return;

    final trimmed = scannedCode.trim().toLowerCase();
    // Match by id, exact name, or batchNo
    final match = medicines.where((m) {
      return m.id.toLowerCase() == trimmed ||
          m.name.toLowerCase() == trimmed ||
          (m.batchNo.isNotEmpty && m.batchNo.toLowerCase() == trimmed) ||
          m.genericName.toLowerCase() == trimmed;
    }).firstOrNull;

    if (match != null) {
      if (match.isExpired) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${match.name} expired on ${DateFormat('dd MMM yyyy').format(match.expiryDate)}! Expired medicines cannot be dispensed.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (match.stock <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${match.name} is out of stock!'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final success = ref.read(cartProvider.notifier).addItem(match.id, match.stock);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanned & added ${match.name} to cart!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot add more of ${match.name}. Max stock: ${match.stock}'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No medicine found matching barcode "$scannedCode".'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  // Confirm and Clear Cart
  void _confirmClearCart(int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Clear Cart?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Clearing the cart will remove all $count item(s) currently staged for billing.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(cartProvider.notifier).clearCart();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cart cleared.')),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  // Execute Sale Generation
  Future<void> _executeSale({
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    required double gstAmount,
    required double grandTotal,
    required dynamic profile,
  }) async {
    final db = ref.read(databaseServiceProvider);
    if (db == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database session not available.')),
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

      final custName = _customerCtrl.text.trim().isNotEmpty
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
        ref.read(cartProvider.notifier).clearCart();
        _customerCtrl.clear();
        _clearSearch();

        // Show Instant Thermal Receipt Dialog
        await BillReceiptDialog.show(
          context,
          sale: completedSale,
          pharmacyName: profile?.pharmacyName ?? 'Klinixy Pharmacy',
          pharmacyAddress: profile != null
              ? '${profile.area}, ${profile.city}'
              : 'Dehradun, Selaqui',
          gstin: profile?.gstin,
          phone: profile?.phone,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process sale: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final medicinesAsync = ref.watch(medicinesStreamProvider);
    final profile = ref.watch(pharmacyProfileProvider).valueOrNull;
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: medicinesAsync.when(
          data: (medicines) {
            final cartItems = cart.entries
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
                        m.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        m.genericName
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        (m.batchNo.isNotEmpty &&
                            m.batchNo
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase())))
                    .take(6)
                    .toList();

            // Keyboard-first shortcuts handler (Escape, Enter, Ctrl+Enter)
            return CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                // Ctrl+Enter / Cmd+Enter triggers billing
                const SingleActivator(LogicalKeyboardKey.enter, control: true):
                    () {
                  if (cartItems.isNotEmpty && !_isProcessing) {
                    _executeSale(
                      cartItems: cartItems,
                      subtotal: subtotal,
                      gstAmount: gstAmount,
                      grandTotal: grandTotal,
                      profile: profile,
                    );
                  }
                },
                const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
                  if (cartItems.isNotEmpty && !_isProcessing) {
                    _executeSale(
                      cartItems: cartItems,
                      subtotal: subtotal,
                      gstAmount: gstAmount,
                      grandTotal: grandTotal,
                      profile: profile,
                    );
                  }
                },
                // Escape clears search
                const SingleActivator(LogicalKeyboardKey.escape): _clearSearch,
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Billing System',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                'Quick walk-in POS & instant receipt generator',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (cartItems.isNotEmpty) ...[
                          TextButton.icon(
                            onPressed: () =>
                                _confirmClearCart(cartItems.length),
                            icon: const Icon(Icons.delete_sweep_outlined,
                                size: 16, color: AppColors.error),
                            label: Text(
                              'Clear',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${cartItems.length} item(s)',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bill Type Selector & Keyboard Shortcut Hints
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
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.2),
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
                          selectedColor:
                              AppColors.warning.withValues(alpha: 0.2),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _billType == 'kaccha'
                                ? AppColors.warning
                                : colors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        // Keyboard shortcut pill
                        Tooltip(
                          message:
                              'Enter: Add top match\nCtrl+Enter: Generate Bill\nEsc: Clear search',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.keyboard_outlined, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Ctrl+⏎ to bill',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
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
                      style: GoogleFonts.inter(
                          fontSize: 13, color: colors.textPrimary),
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

                  // Medicine Search input with Barcode Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      onSubmitted: (v) {
                        // Enter adds the top valid matching result!
                        if (searchResults.isNotEmpty) {
                          final topMed = searchResults.firstWhere(
                            (m) => !m.isExpired && m.stock > 0,
                            orElse: () => searchResults.first,
                          );
                          if (!topMed.isExpired && topMed.stock > 0) {
                            ref
                                .read(cartProvider.notifier)
                                .addItem(topMed.id, topMed.stock);
                            _clearSearch();
                          }
                        }
                      },
                      style: GoogleFonts.inter(
                          fontSize: 13, color: colors.textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText:
                            'Search medicine by name, generic, or batch (Enter to add)...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _clearSearch,
                              ),
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded,
                                  color: AppColors.primary, size: 20),
                              tooltip: 'Scan Barcode',
                              onPressed: () => _startBarcodeScan(medicines),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Search Results Dropdown List
                  if (searchResults.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 6),
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
                          return Container(
                            decoration: BoxDecoration(
                              // Red left-border on expired items
                              border: med.isExpired
                                  ? const Border(
                                      left: BorderSide(
                                          color: AppColors.error, width: 4))
                                  : null,
                            ),
                            child: ListTile(
                              dense: true,
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      med.name,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: med.isExpired
                                            ? AppColors.error
                                            : colors.textPrimary,
                                      ),
                                    ),
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
                                    : '₹${NumberFormat('#,##0.00').format(med.price)} • Stock: ${med.stock}${med.batchNo.isNotEmpty ? " • Batch: ${med.batchNo}" : ""}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: med.isExpired
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: med.isExpired
                                      ? AppColors.error
                                      : colors.textSecondary,
                                ),
                              ),
                              trailing: IconButton(
                                constraints: const BoxConstraints(
                                    minWidth: 48, minHeight: 48),
                                icon: Icon(
                                  med.isExpired
                                      ? Icons.block
                                      : Icons.add_circle,
                                  color: med.isExpired
                                      ? AppColors.error
                                      : AppColors.primary,
                                ),
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
                                                        med.name
                                                            .toLowerCase() ||
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
                                              backgroundColor:
                                                  AppColors.warning,
                                              duration:
                                                  const Duration(seconds: 4),
                                            ),
                                          );
                                        }

                                        if (med.rxRequired) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Schedule H/H1 Warning: ${med.name} requires a doctor prescription.'),
                                              backgroundColor:
                                                  AppColors.accent,
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        }

                                        final added = ref
                                            .read(cartProvider.notifier)
                                            .addItem(med.id, med.stock);
                                        if (added) {
                                          _clearSearch();
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
                                Text(
                                  'No medicines in cart',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Search by name/batch or scan barcode to add',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: colors.textHint),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _searchFocusNode.requestFocus(),
                                  icon: const Icon(Icons.search, size: 16),
                                  label: const Text('Focus Search'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.surfaceLight,
                                    foregroundColor: colors.textPrimary,
                                    minimumSize: const Size(140, 44),
                                  ),
                                ),
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
                                          Text(
                                            med.name,
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                color: colors.textPrimary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₹${NumberFormat('#,##0.00').format(med.price)} each • Stock: ${med.stock}',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: colors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 48px Touch Targets for Steppers
                                    Row(
                                      children: [
                                        IconButton(
                                          constraints: const BoxConstraints(
                                              minWidth: 48, minHeight: 48),
                                          icon: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 22),
                                          onPressed: () {
                                            ref
                                                .read(cartProvider.notifier)
                                                .decrementItem(med.id);
                                          },
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text(
                                            '$qty',
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: colors.textPrimary),
                                          ),
                                        ),
                                        IconButton(
                                          constraints: const BoxConstraints(
                                              minWidth: 48, minHeight: 48),
                                          icon: const Icon(
                                              Icons.add_circle_outline,
                                              size: 22),
                                          onPressed: () {
                                            if (qty < med.stock) {
                                              ref
                                                  .read(cartProvider.notifier)
                                                  .addItem(med.id, med.stock);
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
                                      '₹${NumberFormat('#,##0.00').format(med.price * qty)}',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: colors.textPrimary),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Sticky Checkout Footer (Always Visible, 48px+ targets, Clear Math)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      border:
                          Border(top: BorderSide(color: colors.surfaceLight)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal:',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: colors.textSecondary)),
                            Text('₹${NumberFormat('#,##0.00').format(subtotal)}',
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
                                      fontSize: 12,
                                      color: colors.textSecondary)),
                              Text(
                                  '₹${NumberFormat('#,##0.00').format(gstAmount / 2)}',
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
                                      fontSize: 12,
                                      color: colors.textSecondary)),
                              Text(
                                  '₹${NumberFormat('#,##0.00').format(gstAmount / 2)}',
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
                              Text('Total Tax (itemized GST):',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: colors.textSecondary)),
                              Text(
                                  '₹${NumberFormat('#,##0.00').format(gstAmount)}',
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
                                Text('Grand Total',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: colors.textSecondary)),
                                Text(
                                    '₹${NumberFormat('#,##0.00').format(grandTotal)}',
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
                                  : () => _executeSale(
                                        cartItems: cartItems,
                                        subtotal: subtotal,
                                        gstAmount: gstAmount,
                                        grandTotal: grandTotal,
                                        profile: profile,
                                      ),
                              icon: _isProcessing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.receipt_long_rounded,
                                      size: 18),
                              label: Text(
                                _billType == 'pakka'
                                    ? 'Generate Pakka Bill'
                                    : 'Generate Kaccha Bill',
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(160, 48),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
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
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}
