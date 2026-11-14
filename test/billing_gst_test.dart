import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacist_dashboard/models/medicine.dart';
import 'package:pharmacist_dashboard/models/sale.dart';

void main() {
  group('P7 — Real GST & HSN calculations', () {
    test('Medicine model defaults HSN to 3004 and gstSlab to 12', () {
      final med = Medicine(
        id: 'med1',
        name: 'Paracetamol 500mg',
        category: 'Tablets',
        stock: 100,
        price: 50.0,
        expiryDate: DateTime(2027, 1, 1),
      );

      expect(med.hsn, '3004');
      expect(med.gstSlab, 12);

      final map = med.toMap();
      expect(map['hsn'], '3004');
      expect(map['gstSlab'], 12);

      // Backward compatibility: data without hsn or gstSlab
      final restored = Medicine.fromMap({
        'name': 'Aspirin',
        'category': 'Tablets',
        'stock': 20,
        'price': 30.0,
      }, 'med2');

      expect(restored.hsn, '3004');
      expect(restored.gstSlab, 12);
    });

    test('Mixed-slab Pakka bill calculates itemized CGST + SGST correctly', () {
      // Item 1: 5% GST (e.g. Life-saving drugs / ORS)
      // 2 units @ Rs. 100 = Rs. 200 subtotal, 5% tax = Rs. 10
      final item1 = SaleItem(
        medicineId: 'm1',
        medicineName: 'ORS Sachet',
        quantity: 2,
        unitPrice: 100.0,
        totalPrice: 200.0,
        hsn: '3004',
        gstSlab: 5,
        taxAmount: 200.0 * 0.05, // 10.0
      );

      // Item 2: 12% GST (standard formulations)
      // 3 units @ Rs. 150 = Rs. 450 subtotal, 12% tax = Rs. 54
      final item2 = SaleItem(
        medicineId: 'm2',
        medicineName: 'Amoxicillin 500mg',
        quantity: 3,
        unitPrice: 150.0,
        totalPrice: 450.0,
        hsn: '3004',
        gstSlab: 12,
        taxAmount: 450.0 * 0.12, // 54.0
      );

      // Item 3: 18% GST (disinfectants / medical equipment)
      // 1 unit @ Rs. 300 = Rs. 300 subtotal, 18% tax = Rs. 54
      final item3 = SaleItem(
        medicineId: 'm3',
        medicineName: 'Hand Sanitizer 500ml',
        quantity: 1,
        unitPrice: 300.0,
        totalPrice: 300.0,
        hsn: '3808',
        gstSlab: 18,
        taxAmount: 300.0 * 0.18, // 54.0
      );

      final items = [item1, item2, item3];
      final subtotal = items.fold<double>(0, (sum, i) => sum + i.totalPrice);
      final taxAmount = items.fold<double>(0, (sum, i) => sum + i.taxAmount);
      final grandTotal = subtotal + taxAmount;

      expect(subtotal, 950.0);
      expect(taxAmount, 118.0); // 10 + 54 + 54 = 118
      expect(grandTotal, 1068.0);

      final sale = Sale(
        id: 'sale1',
        billNo: 'PH-2026-0001',
        billType: 'pakka',
        medicineId: item1.medicineId,
        medicineName: item1.medicineName,
        customerName: 'Rohan Sharma',
        quantity: 6,
        unitPrice: 100.0,
        subtotal: subtotal,
        taxAmount: taxAmount,
        totalPrice: grandTotal,
        items: items,
      );

      expect(sale.isPakka, isTrue);
      expect(sale.cgst, 59.0); // 118 / 2
      expect(sale.sgst, 59.0); // 118 / 2
      expect(sale.cgst + sale.sgst, sale.taxAmount);

      final slabTaxes = sale.taxBySlab;
      expect(slabTaxes[5], 10.0);
      expect(slabTaxes[12], 54.0);
      expect(slabTaxes[18], 54.0);
    });

    test('Kaccha bill levies 0 GST', () {
      final item = SaleItem(
        medicineId: 'm1',
        medicineName: 'Paracetamol',
        quantity: 2,
        unitPrice: 50.0,
        totalPrice: 100.0,
        hsn: '3004',
        gstSlab: 12,
        taxAmount: 0.0,
      );

      final sale = Sale(
        id: 'sale2',
        billNo: 'PH-2026-0002',
        billType: 'kaccha',
        medicineId: item.medicineId,
        medicineName: item.medicineName,
        customerName: 'Walk-in',
        quantity: 2,
        unitPrice: 50.0,
        subtotal: 100.0,
        taxAmount: 0.0,
        totalPrice: 100.0,
        items: [item],
      );

      expect(sale.isPakka, isFalse);
      expect(sale.taxAmount, 0.0);
      expect(sale.cgst, 0.0);
      expect(sale.sgst, 0.0);
      expect(sale.totalPrice, sale.subtotal);
    });
  });
}
