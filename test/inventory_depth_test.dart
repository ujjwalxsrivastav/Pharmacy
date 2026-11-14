import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacist_dashboard/models/medicine.dart';
import 'package:pharmacist_dashboard/models/purchase_order.dart';
import 'package:pharmacist_dashboard/models/sale.dart';
import 'package:pharmacist_dashboard/models/supplier.dart';

void main() {
  group('P9 — Inventory Depth: FEFO, Batches, POs, and Returns', () {
    test('Medicine model carries batch, rack, and rxRequired with defaults', () {
      final med = Medicine(
        id: 'med_test',
        name: 'Amoxicillin 500mg',
        category: 'Antibiotics',
        stock: 50,
        price: 80.0,
        batchNo: 'AMX-2026-01',
        rxRequired: true,
        rackShelf: 'A1-S3',
        expiryDate: DateTime(2027, 6, 1),
      );

      expect(med.batchNo, 'AMX-2026-01');
      expect(med.rxRequired, isTrue);
      expect(med.rackShelf, 'A1-S3');

      final map = med.toMap();
      expect(map['batchNo'], 'AMX-2026-01');
      expect(map['rxRequired'], isTrue);
      expect(map['rackShelf'], 'A1-S3');

      // Backward compatibility with legacy documents
      final legacy = Medicine.fromMap({
        'name': 'Cough Syrup',
        'category': 'Syrups',
        'stock': 10,
        'price': 45.0,
      }, 'legacy_doc');

      expect(legacy.batchNo, '');
      expect(legacy.rxRequired, isFalse);
      expect(legacy.rackShelf, '');
    });

    test('FEFO correctly identifies earliest-expiring batch', () {
      final now = DateTime.now();
      final batchEarlier = Medicine(
        id: 'm1',
        name: 'Paracetamol 500mg',
        category: 'Tablets',
        stock: 20,
        price: 25.0,
        batchNo: 'BATCH-EARLY',
        expiryDate: now.add(const Duration(days: 30)),
      );

      final batchLater = Medicine(
        id: 'm2',
        name: 'Paracetamol 500mg',
        category: 'Tablets',
        stock: 50,
        price: 25.0,
        batchNo: 'BATCH-LATE',
        expiryDate: now.add(const Duration(days: 180)),
      );

      final medicines = [batchEarlier, batchLater];

      // Pharmacist attempts to dispense batchLater
      final candidate = batchLater;
      final earlierBatch = medicines.where((m) =>
          m.id != candidate.id &&
          m.stock > 0 &&
          !m.isExpired &&
          m.name.toLowerCase() == candidate.name.toLowerCase() &&
          m.expiryDate.isBefore(candidate.expiryDate)).firstOrNull;

      expect(earlierBatch, isNotNull);
      expect(earlierBatch!.batchNo, 'BATCH-EARLY');
    });

    test('PurchaseOrder and Supplier model contracts', () {
      final supplier = Supplier(
        id: 'sup1',
        name: 'Cipla Distribution Dehradun',
        phone: '+919876543210',
        gstin: '05AAAAA0000A1Z5',
      );

      expect(supplier.name, contains('Cipla'));
      expect(supplier.toMap()['gstin'], '05AAAAA0000A1Z5');

      final item = PurchaseOrderItem(
        medicineId: 'med1',
        medicineName: 'Paracetamol',
        batchNo: 'P2026',
        expiryDate: DateTime(2028, 1, 1),
        quantity: 100,
        unitCost: 15.0,
        totalCost: 1500.0,
      );

      final po = PurchaseOrder(
        id: 'po1',
        poNumber: 'PO-2026-0001',
        supplierId: supplier.id,
        supplierName: supplier.name,
        items: [item],
        totalAmount: 1500.0,
      );

      expect(po.isReceived, isFalse);
      expect(po.items.length, 1);
      expect(po.totalAmount, 1500.0);
    });

    test('Return / Refund calculates negative ledger amounts accurately', () {
      final originalItem = SaleItem(
        medicineId: 'm1',
        medicineName: 'Pain Relief Spray',
        quantity: 2,
        unitPrice: 150.0,
        totalPrice: 300.0,
        hsn: '3004',
        gstSlab: 12,
        taxAmount: 36.0,
      );

      final originalSale = Sale(
        id: 's1',
        billNo: 'PH-2026-1001',
        billType: 'pakka',
        medicineId: originalItem.medicineId,
        medicineName: originalItem.medicineName,
        customerName: 'Aman',
        quantity: 2,
        unitPrice: 150.0,
        subtotal: 300.0,
        taxAmount: 36.0,
        totalPrice: 336.0,
        items: [originalItem],
      );

      // Customer returns 1 item out of 2
      final returnedItem = SaleItem(
        medicineId: originalItem.medicineId,
        medicineName: originalItem.medicineName,
        quantity: 1,
        unitPrice: originalItem.unitPrice,
        totalPrice: originalItem.unitPrice * 1,
        hsn: originalItem.hsn,
        gstSlab: originalItem.gstSlab,
        taxAmount: originalSale.isPakka
            ? (originalItem.unitPrice * 1 * (originalItem.gstSlab / 100.0))
            : 0.0,
      );

      final refundSubtotal = returnedItem.unitPrice * returnedItem.quantity; // 150.0
      final refundTax = originalSale.isPakka
          ? (refundSubtotal * (returnedItem.gstSlab / 100.0)) // 18.0
          : 0.0;
      final refundTotal = refundSubtotal + refundTax; // 168.0

      expect(refundSubtotal, 150.0);
      expect(refundTax, 18.0);
      expect(refundTotal, 168.0);

      final refundSale = Sale(
        id: 'ref1',
        billNo: 'REF-${originalSale.billNo}',
        billType: 'refund',
        medicineId: returnedItem.medicineId,
        medicineName: returnedItem.medicineName,
        customerName: originalSale.customerName,
        quantity: returnedItem.quantity,
        unitPrice: returnedItem.unitPrice,
        subtotal: -refundSubtotal,
        taxAmount: -refundTax,
        totalPrice: -refundTotal,
        items: [returnedItem],
      );

      expect(refundSale.totalPrice, -168.0);
      expect(refundSale.taxAmount, -18.0);
      expect(refundSale.billNo, 'REF-PH-2026-1001');
    });
  });
}

