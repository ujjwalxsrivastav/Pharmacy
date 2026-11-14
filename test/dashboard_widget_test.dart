import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmacist_dashboard/models/medicine.dart';
import 'package:pharmacist_dashboard/models/pharmacy_profile.dart';
import 'package:pharmacist_dashboard/models/sale.dart';
import 'package:pharmacist_dashboard/providers/providers.dart';
import 'package:pharmacist_dashboard/screens/dashboard_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('P13 — Dashboard Widget Tests', () {
    final now = DateTime.now();

    final testProfile = PharmacyProfile(
      uid: 'uid_test',
      email: 'owner@klinixy.com',
      pharmacyName: 'Klinixy Dehradun',
      handlerName: 'Dr. Sharma',
      city: 'Dehradun',
      area: 'Selaqui',
      isOpen: true,
      gstin: '05AAAAA0000A1Z5',
    );

    final seededMedicines = [
      Medicine(
        id: 'med_1',
        name: 'Paracetamol 650mg',
        category: 'Analgesics',
        price: 30.0,
        stock: 5, // Low stock (<= 10)
        reorderLevel: 10,
        expiryDate: now.add(const Duration(days: 100)),
      ),
      Medicine(
        id: 'med_2',
        name: 'Expired Syrup 100ml',
        category: 'Syrups',
        price: 60.0,
        stock: 12,
        reorderLevel: 5,
        expiryDate: now.subtract(const Duration(days: 5)), // Expired
      ),
    ];

    final seededSales = [
      Sale(
        id: 's_1',
        billNo: 'PH-2026-0001',
        medicineId: 'med_1',
        medicineName: 'Paracetamol 650mg',
        quantity: 2,
        unitPrice: 30.0,
        totalPrice: 67.2,
        subtotal: 60.0,
        taxAmount: 7.2,
        date: now,
        billType: 'pakka',
        items: [
          SaleItem(
            medicineId: 'med_1',
            medicineName: 'Paracetamol 650mg',
            quantity: 2,
            unitPrice: 30.0,
            totalPrice: 60.0,
            hsn: '3004',
            gstSlab: 12,
            taxAmount: 7.2,
          ),
        ],
      ),
    ];

    testWidgets('Dashboard renders seeded pharmacy data, stat cards & banners',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pharmacyProfileProvider
                .overrideWith((ref) => Stream.value(testProfile)),
            medicinesStreamProvider
                .overrideWith((ref) => Stream.value(seededMedicines)),
            salesStreamProvider
                .overrideWith((ref) => Stream.value(seededSales)),
            ordersStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verified pharmacy handler and store name rendered
      expect(find.text('Dr. Sharma'), findsOneWidget);
      expect(find.text('Klinixy Dehradun'), findsOneWidget);

      // Verified 4 KPI stat cards exist
      expect(find.text("Today's Revenue"), findsOneWidget);
      expect(find.text("Total Products"), findsOneWidget);
      expect(find.text("Low Stock Items"), findsOneWidget);
      expect(find.text("Expiring Soon"), findsOneWidget);

      // Verified Analytics & Reports banner
      expect(find.textContaining('Analytics & Reports'), findsOneWidget);
    });

    testWidgets('Dashboard renders 0 counts gracefully when empty',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pharmacyProfileProvider
                .overrideWith((ref) => Stream.value(testProfile)),
            medicinesStreamProvider.overrideWith((ref) => Stream.value([])),
            salesStreamProvider.overrideWith((ref) => Stream.value([])),
            ordersStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Today's revenue is 0
      expect(find.text("₹0.00"), findsOneWidget);
      expect(find.text("0 orders today"), findsOneWidget);
    });
  });
}
