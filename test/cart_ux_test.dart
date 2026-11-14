import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacist_dashboard/providers/providers.dart';

void main() {
  group('P11 — UX Polish & Persistent POS Cart Notifier', () {
    test('Cart starts empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(cartProvider), isEmpty);
      expect(container.read(cartTotalUnitsProvider), 0);
      expect(container.read(cartUniqueCountProvider), 0);
    });

    test('addItem increments quantity and respects stock limits', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);

      // Add 2 units with stock 5
      final added1 = notifier.addItem('med_crocin', 5, qty: 2);
      expect(added1, isTrue);
      expect(container.read(cartProvider)['med_crocin'], 2);
      expect(container.read(cartTotalUnitsProvider), 2);
      expect(container.read(cartUniqueCountProvider), 1);

      // Add 3 more units (reaching max stock 5)
      final added2 = notifier.addItem('med_crocin', 5, qty: 3);
      expect(added2, isTrue);
      expect(container.read(cartProvider)['med_crocin'], 5);

      // Attempt to exceed max stock
      final addedExceed = notifier.addItem('med_crocin', 5, qty: 1);
      expect(addedExceed, isFalse);
      expect(container.read(cartProvider)['med_crocin'], 5); // Unchanged
    });

    test('decrementItem reduces quantity and removes when reaching 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      notifier.addItem('med_amox', 10, qty: 2);

      notifier.decrementItem('med_amox');
      expect(container.read(cartProvider)['med_amox'], 1);

      notifier.decrementItem('med_amox');
      expect(container.read(cartProvider).containsKey('med_amox'), isFalse);
      expect(container.read(cartTotalUnitsProvider), 0);
    });

    test('Multiple unique items compute correct units and counts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      notifier.addItem('med_1', 20, qty: 3);
      notifier.addItem('med_2', 15, qty: 5);

      expect(container.read(cartUniqueCountProvider), 2);
      expect(container.read(cartTotalUnitsProvider), 8);

      notifier.removeItem('med_1');
      expect(container.read(cartUniqueCountProvider), 1);
      expect(container.read(cartTotalUnitsProvider), 5);

      notifier.clearCart();
      expect(container.read(cartProvider), isEmpty);
      expect(container.read(cartTotalUnitsProvider), 0);
    });
  });
}

