import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../models/medicine.dart';

class CounterBillingScreen extends ConsumerStatefulWidget {
  const CounterBillingScreen({super.key});

  @override
  ConsumerState<CounterBillingScreen> createState() => _CounterBillingScreenState();
}

class _CounterBillingScreenState extends ConsumerState<CounterBillingScreen> {
  final Map<String, int> _cart = {};
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final medicinesAsync = ref.watch(medicinesStreamProvider);

    return Scaffold(
      body: SafeArea(
        child: medicinesAsync.when(
          data: (medicines) {
            final cartItems = _cart.entries.where((e) => medicines.any((m) => m.id == e.key)).map((e) {
              final med = medicines.firstWhere((m) => m.id == e.key);
              return {'med': med, 'qty': e.value};
            }).toList();

            final total = cartItems.fold<double>(0, (sum, item) {
              final med = item['med'] as Medicine;
              return sum + (med.price * (item['qty'] as int));
            });

            final searchResults = _searchQuery.isEmpty
                ? <Medicine>[]
                : medicines.where((m) =>
                    m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    m.genericName.toLowerCase().contains(_searchQuery.toLowerCase())).take(5).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Text('Counter Billing', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.inter(color: colors.textPrimary),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search medicine to add...',
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                          : null,
                    ),
                  ),
                ),
                if (searchResults.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(color: colors.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.surfaceLight)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: searchResults.map((med) => ListTile(
                        title: Text(med.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                        subtitle: Text('Stock: ${med.stock} • ₹${med.price.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary)),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_shopping_cart, color: AppColors.primary),
                          onPressed: () => setState(() { _cart[med.id] = (_cart[med.id] ?? 0) + 1; _searchCtrl.clear(); _searchQuery = ''; }),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Current Cart', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: cartItems.isEmpty
                      ? Center(child: Text('Cart is empty', style: GoogleFonts.inter(color: colors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: cartItems.length,
                          itemBuilder: (_, i) {
                            final med = cartItems[i]['med'] as Medicine;
                            final qty = cartItems[i]['qty'] as int;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: colors.surfaceCard, borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                  Text(med.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text('₹${med.price.toStringAsFixed(2)} x $qty', style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary)),
                                ])),
                                Row(children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => setState(() { qty > 1 ? _cart[med.id] = qty - 1 : _cart.remove(med.id); }),
                                  ),
                                  Text('$qty', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () {
                                      if (qty < med.stock) {
                                        setState(() => _cart[med.id] = qty + 1);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not enough stock for ${med.name}')));
                                      }
                                    },
                                  ),
                                ]),
                                const SizedBox(width: 8),
                                Text('₹${(med.price * qty).toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: colors.textPrimary)),
                              ]),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: colors.surfaceCard, border: Border(top: BorderSide(color: colors.surfaceLight))),
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('Total Amount', style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary)),
                      Text('₹${total.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                    ]),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: cartItems.isEmpty ? null : () {
                        setState(() => _cart.clear());
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale processed successfully!')));
                      },
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text('Checkout', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ]),
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
