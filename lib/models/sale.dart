import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItem {
  final String medicineId;
  final String medicineName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  SaleItem({
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory SaleItem.fromMap(Map<String, dynamic> data) {
    return SaleItem(
      medicineId: data['medicineId'] ?? '',
      medicineName: data['medicineName'] ?? '',
      quantity: ((data['quantity'] ?? 1) as num).toInt(),
      unitPrice: ((data['unitPrice'] ?? 0.0) as num).toDouble(),
      totalPrice: ((data['totalPrice'] ?? 0.0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'medicineId': medicineId,
        'medicineName': medicineName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
      };
}

class Sale {
  final String id;
  final String billNo;
  final String billType; // 'pakka' or 'kaccha'
  final String medicineId;
  final String medicineName;
  final String customerName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final double taxAmount; // GST (18%) for pakka bill
  final double totalPrice;
  final List<SaleItem> items;
  final DateTime date;

  Sale({
    required this.id,
    String? billNo,
    this.billType = 'pakka',
    required this.medicineId,
    required this.medicineName,
    this.customerName = 'Walk-in',
    required this.quantity,
    required this.unitPrice,
    double? subtotal,
    double? taxAmount,
    required this.totalPrice,
    List<SaleItem>? items,
    DateTime? date,
  })  : billNo = billNo ?? DateTime.now().millisecondsSinceEpoch.toString().substring(7),
        subtotal = subtotal ?? totalPrice,
        taxAmount = taxAmount ?? (billType == 'pakka' ? totalPrice * 0.18 / 1.18 : 0.0),
        items = items ??
            [
              SaleItem(
                medicineId: medicineId,
                medicineName: medicineName,
                quantity: quantity,
                unitPrice: unitPrice,
                totalPrice: totalPrice,
              )
            ],
        date = date ?? DateTime.now();

  bool get isPakka => billType == 'pakka';

  factory Sale.fromMap(Map<String, dynamic> data, String documentId) {
    final rawItems = data['items'] as List<dynamic>?;
    final itemsList = rawItems != null
        ? rawItems.map((e) => SaleItem.fromMap(Map<String, dynamic>.from(e))).toList()
        : <SaleItem>[];

    final total = (data['totalPrice'] ?? 0.0).toDouble();
    final bType = data['billType'] ?? 'pakka';
    final tax = data['taxAmount'] != null
        ? (data['taxAmount'] as num).toDouble()
        : (bType == 'pakka' ? (total * 0.18 / 1.18) : 0.0);

    return Sale(
      id: documentId,
      billNo: data['billNo'] ?? documentId.substring(0, documentId.length > 6 ? 6 : documentId.length),
      billType: bType,
      medicineId: data['medicineId'] ?? (itemsList.isNotEmpty ? itemsList.first.medicineId : ''),
      medicineName: data['medicineName'] ?? (itemsList.isNotEmpty ? itemsList.first.medicineName : 'Medicine'),
      customerName: data['customerName'] ?? 'Walk-in',
      quantity: ((data['quantity'] ?? (itemsList.isNotEmpty ? itemsList.fold(0, (s, i) => s + i.quantity) : 1)) as num).toInt(),
      unitPrice: ((data['unitPrice'] ?? 0.0) as num).toDouble(),
      subtotal: data['subtotal'] != null ? (data['subtotal'] as num).toDouble() : (total - tax),
      taxAmount: tax,
      totalPrice: total,
      items: itemsList.isNotEmpty
          ? itemsList
          : [
              SaleItem(
                medicineId: data['medicineId'] ?? '',
                medicineName: data['medicineName'] ?? '',
                quantity: (data['quantity'] ?? 1) as int,
                unitPrice: (data['unitPrice'] ?? 0.0).toDouble(),
                totalPrice: total,
              )
            ],
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'billNo': billNo,
      'billType': billType,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'customerName': customerName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'totalPrice': totalPrice,
      'items': items.map((i) => i.toMap()).toList(),
      'date': Timestamp.fromDate(date),
    };
  }
}
