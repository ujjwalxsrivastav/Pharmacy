import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacist_dashboard/models/medicine.dart';
import 'package:pharmacist_dashboard/models/sale.dart';

void main() {
  group('P10 — Unified Analytics & Financial Reports Calculations', () {
    final now = DateTime.now();

    final testMedicines = [
      Medicine(
        id: 'med_paracetamol',
        name: 'Paracetamol 500mg',
        category: 'Analgesics',
        price: 20.0,
        stock: 50,
        reorderLevel: 10,
        expiryDate: now.add(const Duration(days: 300)),
        hsn: '3004',
        gstSlab: 12,
      ),
      Medicine(
        id: 'med_azithral',
        name: 'Azithral 500mg',
        category: 'Antibiotics',
        price: 120.0,
        stock: 25,
        reorderLevel: 5,
        expiryDate: now.add(const Duration(days: 400)),
        hsn: '3004',
        gstSlab: 12,
      ),
      Medicine(
        id: 'med_slow',
        name: 'Rare Cream 10g',
        category: 'Dermatology',
        price: 350.0,
        stock: 15,
        reorderLevel: 3,
        expiryDate: now.add(const Duration(days: 500)),
        hsn: '3004',
        gstSlab: 18,
      ),
    ];

    final testSales = [
      // Today sale (Pakka)
      Sale(
        id: 'sale_1',
        billNo: 'PH-2026-0001',
        customerName: 'Aman',
        medicineId: 'med_paracetamol',
        medicineName: 'Paracetamol 500mg',
        quantity: 2,
        unitPrice: 20.0,
        totalPrice: 44.8,
        subtotal: 40.0,
        taxAmount: 4.8,
        date: DateTime(now.year, now.month, now.day, 14, 30), // 2:30 PM
        billType: 'pakka',
        items: [
          SaleItem(
            medicineId: 'med_paracetamol',
            medicineName: 'Paracetamol 500mg',
            quantity: 2,
            unitPrice: 20.0,
            totalPrice: 40.0,
            hsn: '3004',
            gstSlab: 12,
            taxAmount: 4.8,
          ),
        ],
      ),
      // Today sale (Kaccha)
      Sale(
        id: 'sale_2',
        billNo: 'PH-2026-0002',
        customerName: 'Priya',
        medicineId: 'med_azithral',
        medicineName: 'Azithral 500mg',
        quantity: 1,
        unitPrice: 120.0,
        totalPrice: 120.0,
        subtotal: 120.0,
        taxAmount: 0.0,
        date: DateTime(now.year, now.month, now.day, 14, 45), // 2:45 PM
        billType: 'kaccha',
        items: [
          SaleItem(
            medicineId: 'med_azithral',
            medicineName: 'Azithral 500mg',
            quantity: 1,
            unitPrice: 120.0,
            totalPrice: 120.0,
            hsn: '3004',
            gstSlab: 12,
            taxAmount: 0.0,
          ),
        ],
      ),
      // 3 days ago sale (Pakka)
      Sale(
        id: 'sale_3',
        billNo: 'PH-2026-0003',
        customerName: 'Rahul',
        medicineId: 'med_paracetamol',
        medicineName: 'Paracetamol 500mg',
        quantity: 5,
        unitPrice: 20.0,
        totalPrice: 112.0,
        subtotal: 100.0,
        taxAmount: 12.0,
        date: now.subtract(const Duration(days: 3)),
        billType: 'pakka',
        items: [
          SaleItem(
            medicineId: 'med_paracetamol',
            medicineName: 'Paracetamol 500mg',
            quantity: 5,
            unitPrice: 20.0,
            totalPrice: 100.0,
            hsn: '3004',
            gstSlab: 12,
            taxAmount: 12.0,
          ),
        ],
      ),
    ];

    test('4 Stat KPI cards compute accurate metrics for range', () {
      final todaySales = testSales
          .where((s) =>
              s.date.year == now.year &&
              s.date.month == now.month &&
              s.date.day == now.day)
          .toList();

      final totalRevenue =
          todaySales.fold<double>(0, (sum, s) => sum + s.totalPrice);
      final pakkaCount = todaySales.where((s) => s.isPakka).length;
      final kacchaCount = todaySales.where((s) => !s.isPakka).length;
      final totalGst = todaySales
          .where((s) => s.isPakka)
          .fold<double>(0, (sum, s) => sum + s.taxAmount);
      final avgOrderValue =
          todaySales.isNotEmpty ? totalRevenue / todaySales.length : 0.0;

      expect(totalRevenue, closeTo(164.8, 0.01));
      expect(pakkaCount, 1);
      expect(kacchaCount, 1);
      expect(totalGst, closeTo(4.8, 0.01));
      expect(avgOrderValue, closeTo(82.4, 0.01));
    });

    test('24-hour peak sales hour correctly detects 2PM (hour 14) as peak', () {
      final hourlyCounts = List<int>.filled(24, 0);
      for (final sale in testSales) {
        hourlyCounts[sale.date.hour] += 1;
      }

      int maxHourIdx = 0;
      int maxHourVal = 0;
      for (int i = 0; i < hourlyCounts.length; i++) {
        if (hourlyCounts[i] > maxHourVal) {
          maxHourVal = hourlyCounts[i];
          maxHourIdx = i;
        }
      }

      expect(maxHourIdx, 14); // 2:00 PM
      expect(maxHourVal, 2); // 2 orders placed at hour 14
    });

    test('Top Selling Items aggregates correctly by units sold', () {
      final itemMap = <String, Map<String, dynamic>>{};
      for (final sale in testSales) {
        for (final item in sale.items) {
          final key = item.medicineName.toLowerCase();
          if (!itemMap.containsKey(key)) {
            itemMap[key] = {
              'name': item.medicineName,
              'qty': 0,
              'revenue': 0.0,
            };
          }
          itemMap[key]!['qty'] =
              (itemMap[key]!['qty'] as int) + item.quantity;
          itemMap[key]!['revenue'] =
              (itemMap[key]!['revenue'] as double) + item.totalPrice;
        }
      }

      final list = itemMap.values.toList();
      list.sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));

      expect(list.first['name'], 'Paracetamol 500mg');
      expect(list.first['qty'], 7); // 2 today + 5 3 days ago
      expect(list[1]['name'], 'Azithral 500mg');
      expect(list[1]['qty'], 1);
    });

    test(
        'Slow Moving Stock identifies unsold medicines with active inventory',
        () {
      final soldQuantities = <String, int>{};
      for (final sale in testSales) {
        for (final item in sale.items) {
          final key = item.medicineId.isNotEmpty
              ? item.medicineId
              : item.medicineName.toLowerCase();
          soldQuantities[key] =
              (soldQuantities[key] ?? 0) + (item.quantity as num).toInt();
        }
      }

      final slowMoving = <Medicine>[];
      for (final m in testMedicines) {
        if (m.stock > 0) {
          final sold = soldQuantities[m.id] ?? 0;
          if (sold <= 2) {
            slowMoving.add(m);
          }
        }
      }

      expect(slowMoving.any((m) => m.name == 'Rare Cream 10g'), isTrue);
      expect(slowMoving.any((m) => m.name == 'Azithral 500mg'), isTrue);
      expect(slowMoving.any((m) => m.name == 'Paracetamol 500mg'), isFalse);
    });

    test('Category Revenue Breakdown calculates percentage of gross total', () {
      final medCategoryMap = <String, String>{
        for (final m in testMedicines) m.id: m.category,
      };

      final catRev = <String, double>{};
      for (final sale in testSales) {
        for (final item in sale.items) {
          final cat = medCategoryMap[item.medicineId] ?? 'Other';
          catRev[cat] = (catRev[cat] ?? 0.0) + item.totalPrice;
        }
      }

      final total = catRev.values.fold<double>(0, (sum, v) => sum + v);
      expect(catRev['Analgesics'], 140.0);
      expect(catRev['Antibiotics'], 120.0);
      expect(total, 260.0);

      final analgesicsPct = (catRev['Analgesics']! / total) * 100;
      expect(analgesicsPct, closeTo(53.8, 0.1));
    });

    test('Custom date range filtering includes only sales within range', () {
      final customRange = DateTimeRange(
        start: now.subtract(const Duration(days: 4)),
        end: now.subtract(const Duration(days: 2)),
      );

      final start = DateTime(customRange.start.year, customRange.start.month,
          customRange.start.day);
      final end = DateTime(customRange.end.year, customRange.end.month,
              customRange.end.day)
          .add(const Duration(days: 1));

      final inRange = testSales
          .where((s) =>
              s.date.isAfter(
                  start.subtract(const Duration(milliseconds: 1))) &&
              s.date.isBefore(end))
          .toList();

      expect(inRange.length, 1);
      expect(inRange.first.billNo, 'PH-2026-0003');
    });
  });
}
