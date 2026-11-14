import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacist_dashboard/utils/demo_seeder.dart';

void main() {
  group('P14 — Demo Data Seeder Verification', () {
    test('getDemoMedicines generates exactly 20 diverse medicines', () {
      final meds = DemoDataSeeder.getDemoMedicines();
      expect(meds.length, 20);

      // Verify category diversity
      final categories = meds.map((m) => m.category).toSet();
      expect(categories.length, greaterThanOrEqualTo(8));

      // Verify batch and rack/shelf assignments
      expect(meds.every((m) => m.batchNo.isNotEmpty), isTrue);
      expect(meds.every((m) => m.rackShelf.isNotEmpty), isTrue);

      // Verify GST slabs representation (5%, 12%, 18%)
      final slabs = meds.map((m) => m.gstSlab).toSet();
      expect(slabs.contains(5), isTrue);
      expect(slabs.contains(12), isTrue);
      expect(slabs.contains(18), isTrue);
    });

    test('getDemoSales generates 30 days of balanced sales history', () {
      final sales = DemoDataSeeder.getDemoSales();
      expect(sales.length, 30);

      // Check sequential bill numbers
      expect(sales.first.billNo, 'PH-2026-1000');
      expect(sales.last.billNo, 'PH-2026-1029');

      // Both Pakka and Kaccha present
      final hasPakka = sales.any((s) => s.isPakka);
      final hasKaccha = sales.any((s) => !s.isPakka);
      expect(hasPakka, isTrue);
      expect(hasKaccha, isTrue);

      // Dates span back up to 29 days
      final now = DateTime.now();
      final earliest = sales.last.date;
      final diff = now.difference(earliest).inDays;
      expect(diff, greaterThanOrEqualTo(28));
    });
  });
}

