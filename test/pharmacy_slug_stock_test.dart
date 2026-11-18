import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacist_dashboard/models/medicine.dart';
import 'package:pharmacist_dashboard/services/database_service.dart';

void main() {
  group('Pharmacy Slug & Multi-Path Stock Architecture Tests', () {
    test('slugify transforms pharmacy names to clean folder slugs', () {
      expect(
        DatabaseService.slugify('Garhwal Medical Store'),
        'garhwal-medical-store',
      );
      expect(
        DatabaseService.slugify('Dhulkot Medicos'),
        'dhulkot-medicos',
      );
      expect(
        DatabaseService.slugify('Dhulkot Care'),
        'dhulkot-care',
      );
      expect(
        DatabaseService.slugify('Dr. Sharma & Sons Pharmacy 24/7!'),
        'dr-sharma-sons-pharmacy-24-7',
      );
    });

    test('PharmacyLocation preserves clean slug docId and legacyDocId tracking', () {
      const loc = PharmacyLocation(
        docId: 'garhwal-medical-store',
        path: 'pharmacies/garhwal-medical-store',
        city: 'Dehradun',
        area: 'Selaqui',
        cityId: 'dehradun',
        areaId: 'selaqui',
        pharmacyName: 'Garhwal Medical Store',
        legacyDocId: 'CXnweu0t8raPUdhwReZsLeYtFt13',
      );

      expect(loc.docId, 'garhwal-medical-store');
      expect(loc.path, 'pharmacies/garhwal-medical-store');
      expect(loc.legacyDocId, 'CXnweu0t8raPUdhwReZsLeYtFt13');
      expect(loc.pharmacyName, 'Garhwal Medical Store');
    });

    test('Medicine model toMap serializes stock and inventory metadata correctly', () {
      final now = DateTime.now();
      final med = Medicine(
        id: 'med_paracetamol',
        name: 'Paracetamol 650mg',
        category: 'Analgesics',
        price: 30.0,
        stock: 50,
        reorderLevel: 10,
        expiryDate: now.add(const Duration(days: 180)),
        batchNo: 'B-2026-01',
        manufacturer: 'Micro Labs',
        rackShelf: 'Shelf A1',
      );

      final map = med.toMap();
      expect(map['name'], 'Paracetamol 650mg');
      expect(map['stock'], 50);
      expect(map['price'], 30.0);
      expect(map['batchNo'], 'B-2026-01');
      expect(map['manufacturer'], 'Micro Labs');
      expect(map['rackShelf'], 'Shelf A1');
    });
  });
}

