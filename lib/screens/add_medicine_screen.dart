import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../models/medicine.dart';
import '../models/sale.dart';

class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _genericCtrl = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _reorderCtrl = TextEditingController();
  String _category = 'Other';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  bool _isLoading = false;

  final _categories = ['Pain Relief', 'Antibiotics', 'Allergy', 'Diabetes', 'Cardiovascular', 'Gastrointestinal', 'Vitamins', 'Dermatology', 'Other'];

  @override
  void dispose() {
    _nameCtrl.dispose(); _genericCtrl.dispose(); _manufacturerCtrl.dispose();
    _priceCtrl.dispose(); _costCtrl.dispose(); _stockCtrl.dispose(); _reorderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Add Medicine', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildField('Medicine Name *', _nameCtrl, colors, validator: (v) => v!.isEmpty ? 'Required' : null),
            _buildField('Generic Name', _genericCtrl, colors),
            _buildField('Manufacturer', _manufacturerCtrl, colors),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Category', style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: colors.surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _category, isExpanded: true, dropdownColor: colors.surface,
                      style: GoogleFonts.inter(color: colors.textPrimary),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                  ),
                ),
              ]),
            ),
            Row(children: [
              Expanded(child: _buildField('Selling Price (₹) *', _priceCtrl, colors, keyboard: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: _buildField('Cost Price (₹)', _costCtrl, colors, keyboard: TextInputType.number)),
            ]),
            Row(children: [
              Expanded(child: _buildField('Stock Qty *', _stockCtrl, colors, keyboard: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: _buildField('Reorder Level', _reorderCtrl, colors, keyboard: TextInputType.number)),
            ]),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Expiry Date *', style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _expiryDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
                    if (picked != null) setState(() => _expiryDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: colors.surfaceLight, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Text('${_expiryDate.day}/${_expiryDate.month}/${_expiryDate.year}', style: GoogleFonts.inter(color: colors.textPrimary)),
                      const Spacer(),
                      Icon(Icons.calendar_today_outlined, size: 18, color: colors.textSecondary),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveMedicine,
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Save Medicine', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final medicine = Medicine(
        id: '',
        name: _nameCtrl.text.trim(),
        genericName: _genericCtrl.text.trim(),
        category: _category,
        manufacturer: _manufacturerCtrl.text.trim(),
        stock: int.tryParse(_stockCtrl.text) ?? 0,
        reorderLevel: int.tryParse(_reorderCtrl.text) ?? 10,
        price: double.tryParse(_priceCtrl.text) ?? 0,
        costPrice: double.tryParse(_costCtrl.text) ?? 0,
        expiryDate: _expiryDate,
      );
      await ref.read(databaseServiceProvider).addMedicine(medicine);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildField(String label, TextEditingController ctrl, AppColors colors, {TextInputType? keyboard, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(controller: ctrl, keyboardType: keyboard, validator: validator, style: GoogleFonts.inter(color: colors.textPrimary)),
      ]),
    );
  }
}
