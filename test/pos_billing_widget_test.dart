import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmacist_dashboard/models/medicine.dart';
import 'package:pharmacist_dashboard/models/pharmacy_profile.dart';
import 'package:pharmacist_dashboard/providers/providers.dart';
import 'package:pharmacist_dashboard/screens/counter_billing_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('P13 — Counter Billing POS Widget Tests', () {
    final now = DateTime.now();

    final testProfile = PharmacyProfile(
      uid: 'uid_test',
      email: 'owner@klinixy.com',
      pharmacyName: 'Klinixy Pharmacy',
      handlerName: 'Pharmacist',
      city: 'Dehradun',
      area: 'Selaqui',
      isOpen: true,
      gstin: '05AAAAA0000A1Z5',
    );

    final testMedicines = [
      Medicine(
        id: 'med_pcm',
        name: 'Paracetamol 500mg',
        category: 'Tablets',
        price: 20.0,
        stock: 50,
        reorderLevel: 10,
        expiryDate: now.add(const Duration(days: 300)),
        hsn: '3004',
        gstSlab: 12,
      ),
      Medicine(
        id: 'med_exp',
        name: 'Expired Antibiotic',
        category: 'Antibiotics',
        price: 100.0,
        stock: 10,
        reorderLevel: 5,
        expiryDate: now.subtract(const Duration(days: 10)), // Expired
        hsn: '3004',
        gstSlab: 12,
      ),
    ];

    testWidgets('Empty cart displays guidance and focus search CTA',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pharmacyProfileProvider
                .overrideWith((ref) => Stream.value(testProfile)),
            medicinesStreamProvider
                .overrideWith((ref) => Stream.value(testMedicines)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CounterBillingScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No medicines in cart'), findsOneWidget);
      expect(find.text('Focus Search'), findsOneWidget);
      expect(find.text('Generate Pakka Bill'), findsOneWidget);
    });

    testWidgets('Staged item displays correct subtotal, CGST, SGST, and Grand Total',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          pharmacyProfileProvider
              .overrideWith((ref) => Stream.value(testProfile)),
          medicinesStreamProvider
              .overrideWith((ref) => Stream.value(testMedicines)),
        ],
      );
      addTearDown(container.dispose);

      // Pre-add 2 Paracetamol into Riverpod cart
      container.read(cartProvider.notifier).addItem('med_pcm', 50, qty: 2);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CounterBillingScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Item in cart list
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Calculations: 2 x 20 = 40 subtotal. 12% GST = 4.80. CGST = 2.40, SGST = 2.40. Total = 44.80.
      expect(find.text('₹40.00'), findsWidgets); // subtotal
      expect(find.text('₹2.40'), findsNWidgets(2)); // CGST and SGST
      expect(find.text('₹44.80'), findsOneWidget); // Grand Total
    });
  });
}
