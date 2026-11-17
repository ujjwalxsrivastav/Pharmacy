import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacist_dashboard/models/medicine.dart';
import 'package:pharmacist_dashboard/services/database_service.dart';

void main() {
  group('Klinixy Frontend Ecosystem Stock Sync Tests', () {
    test('slugify converts titles and brand names to clean url-safe slugs', () {
      expect(DatabaseService.slugify('1-AL Tablet FDC Ltd'), '1-al-tablet-fdc-ltd');
      expect(DatabaseService.slugify('Human Insulatard 40IU/ml Novo Nordisk'),
          'human-insulatard-40iu-ml-novo-nordisk');
      expect(DatabaseService.slugify('Dolo 650 (Paracetamol)'), 'dolo-650-paracetamol');
      expect(DatabaseService.slugify('   A to Z NS   '), 'a-to-z-ns');
      expect(DatabaseService.slugify('Crocin Advance 500mg'), 'crocin-advance-500mg');
    });

    test('buildEcosystemStockPayload creates complete dictionary matching customer app schema', () {
      final location = const PharmacyLocation(
        docId: 'rajpur-road-care',
        path: 'pharmacies/rajpur-road-care',
        city: 'Dehradun',
        area: 'Rajpur Road',
        cityId: 'dehradun',
        areaId: 'rajpur-road',
        pharmacyName: 'Rajpur Road Care Pharmacy',
      );

      final db = DatabaseService(location: location);
      final med = Medicine(
        id: 'test-med-123',
        name: 'Crocin 650 Tablet',
        genericName: 'Paracetamol 650mg',
        category: 'Pain Relief',
        manufacturer: 'GSK Consumer',
        stock: 45,
        reorderLevel: 10,
        price: 32.50,
        costPrice: 25.00,
        hsn: '3004',
        gstSlab: 12,
        batchNo: 'B9921',
        rxRequired: false,
        rackShelf: 'R1-S2',
        expiryDate: DateTime(2027, 5, 20),
      );

      final slug = DatabaseService.slugify('${med.name} ${med.manufacturer}');
      final payload = db.buildEcosystemStockPayload(
        id: 'test-med-123',
        medicine: med,
        slug: slug,
      );

      // 1. Identification fields
      expect(payload['id'], 'test-med-123');
      expect(payload['medicineId'], 'test-med-123');
      expect(payload['productId'], 'test-med-123');
      expect(payload['slug'], 'crocin-650-tablet-gsk-consumer');

      // 2. Name variants expected by customer frontend
      expect(payload['name'], 'Crocin 650 Tablet');
      expect(payload['medicineName'], 'Crocin 650 Tablet');
      expect(payload['productName'], 'Crocin 650 Tablet');
      expect(payload['title'], 'Crocin 650 Tablet');

      // 3. Brand & composition
      expect(payload['brand'], 'GSK Consumer');
      expect(payload['brandName'], 'GSK Consumer');
      expect(payload['manufacturer'], 'GSK Consumer');
      expect(payload['composition'], 'Paracetamol 650mg');
      expect(payload['genericName'], 'Paracetamol 650mg');

      // 4. Pricing
      expect(payload['price'], 32.50);
      expect(payload['sellingPrice'], 32.50);
      expect(payload['rate'], 32.50);
      expect(payload['mrp'], greaterThanOrEqualTo(32.50));

      // 5. Stock counts & availability flags
      expect(payload['stock'], 45);
      expect(payload['stockCount'], 45);
      expect(payload['quantity'], 45);
      expect(payload['qty'], 45);
      expect(payload['inStock'], true);
      expect(payload['available'], true);
      expect(payload['isActive'], true);

      // 6. Pharmacy context
      expect(payload['pharmacyId'], 'rajpur-road-care');
      expect(payload['pharmacyName'], 'Rajpur Road Care Pharmacy');
      expect(payload['cityId'], 'dehradun');
      expect(payload['areaId'], 'rajpur-road');

      // 7. Prescription flags
      expect(payload['requiresPrescription'], false);
      expect(payload['isPrescriptionRequired'], false);
      expect(payload['rxRequired'], false);

      // 8. Tags & discovery
      final tags = payload['tags'] as List<String>;
      expect(tags, contains('Pain Relief'));
      expect(tags, contains('Crocin 650 Tablet'));
      expect(tags, contains('Rajpur Road Care Pharmacy'));
    });

    test('buildEcosystemStockPayload marks zero stock as out of stock', () {
      final location = const PharmacyLocation(
        docId: 'test-pharmacy',
        path: 'pharmacies/test-pharmacy',
        city: 'Dehradun',
        area: 'Selaqui',
      );

      final db = DatabaseService(location: location);
      final med = Medicine(
        id: 'zero-stock-med',
        name: 'Empty Medicine',
        category: 'Antibiotics',
        stock: 0,
        price: 50.0,
        expiryDate: DateTime(2027, 1, 1),
      );

      final payload = db.buildEcosystemStockPayload(
        id: 'zero-stock-med',
        medicine: med,
        slug: 'empty-medicine',
      );

      expect(payload['stock'], 0);
      expect(payload['stockCount'], 0);
      expect(payload['inStock'], false);
      expect(payload['available'], false);
    });

    test('Medicine copyWith supports updating document id', () {
      final med = Medicine(
        id: '',
        name: 'Dolo 650',
        category: 'Pain Relief',
        stock: 10,
        price: 30,
        expiryDate: DateTime(2027, 1, 1),
      );

      final updated = med.copyWith(id: 'assigned-doc-id-999');
      expect(updated.id, 'assigned-doc-id-999');
      expect(updated.name, 'Dolo 650');
      expect(updated.stock, 10);
    });
  });
}
