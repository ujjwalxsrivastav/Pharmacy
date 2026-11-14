import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacist_dashboard/services/order_contract.dart';

void main() {
  group('P8 — Quick-Commerce Order Contract', () {
    test('KlinixyOrder parses fields, items and statusHistory correctly', () {
      final now = DateTime.now();
      final item1 = OrderItem(
        medicineId: 'med_123',
        medicineName: 'Azithromycin 500mg',
        quantity: 2,
        unitPrice: 120.0,
        totalPrice: 240.0,
      );

      final order = KlinixyOrder(
        id: 'ord_abc123',
        pharmacyId: 'Test',
        customerId: 'cust_999',
        customerName: 'Ananya Verma',
        customerPhone: '+919876543210',
        deliveryAddress: 'House 14, Rajpur Road, Dehradun',
        deliveryLocation: const GeoPoint(30.3165, 78.0322),
        items: [item1],
        subtotal: 240.0,
        deliveryFee: 40.0,
        total: 280.0,
        paymentMethod: 'UPI',
        paymentStatus: 'paid',
        status: 'placed',
        createdAt: now,
        updatedAt: now,
        statusHistory: [
          OrderStatusEntry(
            status: 'placed',
            at: now,
            by: 'cust_999',
          ),
        ],
      );

      expect(order.isPlaced, isTrue);
      expect(order.isAccepted, isFalse);
      expect(order.items.length, 1);
      expect(order.items.first.totalPrice, 240.0);
      expect(order.total, 280.0);
      expect(order.statusHistory.length, 1);
      expect(order.statusHistory.first.status, 'placed');

      final map = order.toMap();
      expect(map['pharmacyId'], 'Test');
      expect(map['customerName'], 'Ananya Verma');
      expect(map['total'], 280.0);
      expect(map['status'], 'placed');
      expect((map['items'] as List).length, 1);
    });

    test('Order rejection logs reason and updates state', () {
      final now = DateTime.now();
      final order = KlinixyOrder(
        id: 'ord_rej1',
        pharmacyId: 'Test',
        customerId: 'cust_111',
        customerName: 'Rohan',
        customerPhone: '+919876500000',
        deliveryAddress: 'Clock Tower, Dehradun',
        items: [],
        subtotal: 100.0,
        total: 100.0,
        status: 'rejected',
        rejectionReason: 'Out of stock: Paracetamol batch exhausted',
        statusHistory: [
          OrderStatusEntry(
            status: 'placed',
            at: now.subtract(const Duration(minutes: 5)),
            by: 'cust_111',
          ),
          OrderStatusEntry(
            status: 'rejected',
            at: now,
            by: 'pharmacy_staff',
            reason: 'Out of stock: Paracetamol batch exhausted',
          ),
        ],
      );

      expect(order.isRejected, isTrue);
      expect(order.rejectionReason, contains('Out of stock'));
      expect(order.statusHistory.length, 2);
      expect(order.statusHistory.last.reason, isNotNull);
    });
  });
}
