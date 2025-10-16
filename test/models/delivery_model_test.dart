// test/models/delivery_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cold_storage/models/delivery_model.dart';

void main() {
  group('Delivery Model Tests', () {
    final testTimestamp = Timestamp.fromDate(DateTime(2025, 1, 20));

    test('Delivery constructor creates instance with required fields', () {
      final delivery = Delivery(
        coldStorageName: 'Cold Storage A',
        receiptNumber: 'R001',
        quantity: 50,
        narration: 'First delivery',
        deliveryDate: testTimestamp,
      );

      expect(delivery.coldStorageName, 'Cold Storage A');
      expect(delivery.receiptNumber, 'R001');
      expect(delivery.quantity, 50);
      expect(delivery.narration, 'First delivery');
      expect(delivery.deliveryDate, testTimestamp);
      expect(delivery.id, isNull);
    });

    test('Delivery constructor accepts optional id', () {
      final delivery = Delivery(
        id: 'delivery123',
        coldStorageName: 'Cold Storage B',
        receiptNumber: 'R002',
        quantity: 75,
        narration: 'Second delivery',
        deliveryDate: testTimestamp,
      );

      expect(delivery.id, 'delivery123');
      expect(delivery.coldStorageName, 'Cold Storage B');
      expect(delivery.receiptNumber, 'R002');
      expect(delivery.quantity, 75);
      expect(delivery.narration, 'Second delivery');
    });

    test('toJson converts Delivery to Map correctly', () {
      final delivery = Delivery(
        coldStorageName: 'Cold Storage C',
        receiptNumber: 'R003',
        quantity: 100,
        narration: 'JSON conversion test',
        deliveryDate: testTimestamp,
      );

      final json = delivery.toJson();

      expect(json['coldStorageName'], 'Cold Storage C');
      expect(json['receiptNumber'], 'R003');
      expect(json['quantity'], 100);
      expect(json['narration'], 'JSON conversion test');
      expect(json['deliveryDate'], testTimestamp);
      expect(json.containsKey('id'), false); // id should not be in JSON
    });

    test('toJson handles empty narration', () {
      final delivery = Delivery(
        coldStorageName: 'Cold Storage D',
        receiptNumber: 'R004',
        quantity: 25,
        narration: '',
        deliveryDate: testTimestamp,
      );

      final json = delivery.toJson();

      expect(json['narration'], '');
      expect(json['narration'].isEmpty, true);
    });

    test('Quantity field accepts integer values', () {
      final delivery = Delivery(
        coldStorageName: 'Cold Storage E',
        receiptNumber: 'R005',
        quantity: 200,
        narration: 'Large quantity',
        deliveryDate: testTimestamp,
      );

      expect(delivery.quantity, 200);
      expect(delivery.quantity, isA<int>());
    });

    test('DeliveryDate field stores Timestamp correctly', () {
      final specificDate = DateTime(2025, 3, 15, 10, 30);
      final timestamp = Timestamp.fromDate(specificDate);

      final delivery = Delivery(
        coldStorageName: 'Cold Storage F',
        receiptNumber: 'R006',
        quantity: 150,
        narration: 'Date test',
        deliveryDate: timestamp,
      );

      expect(delivery.deliveryDate, timestamp);
      expect(delivery.deliveryDate.toDate(), specificDate);
    });

    test('Multiple deliveries with same receipt number are allowed', () {
      final delivery1 = Delivery(
        id: 'delivery1',
        coldStorageName: 'Cold Storage G',
        receiptNumber: 'R007',
        quantity: 30,
        narration: 'First partial delivery',
        deliveryDate: testTimestamp,
      );

      final delivery2 = Delivery(
        id: 'delivery2',
        coldStorageName: 'Cold Storage G',
        receiptNumber: 'R007',
        quantity: 40,
        narration: 'Second partial delivery',
        deliveryDate: testTimestamp,
      );

      expect(delivery1.receiptNumber, delivery2.receiptNumber);
      expect(delivery1.id, isNot(equals(delivery2.id)));
      expect(delivery1.quantity, 30);
      expect(delivery2.quantity, 40);
    });

    test('Delivery handles long narration text', () {
      final longNarration = 'This is a very long narration that contains '
          'detailed information about the delivery including customer details, '
          'vehicle information, and special handling instructions.';

      final delivery = Delivery(
        coldStorageName: 'Cold Storage H',
        receiptNumber: 'R008',
        quantity: 60,
        narration: longNarration,
        deliveryDate: testTimestamp,
      );

      expect(delivery.narration, longNarration);
      expect(delivery.narration.length, greaterThan(100));
    });

    test('Delivery handles special characters in fields', () {
      final delivery = Delivery(
        coldStorageName: 'Cold Storage & Co.',
        receiptNumber: 'R-009/2025',
        quantity: 85,
        narration: 'Delivery @Location #5 (Urgent!)',
        deliveryDate: testTimestamp,
      );

      expect(delivery.coldStorageName, 'Cold Storage & Co.');
      expect(delivery.receiptNumber, 'R-009/2025');
      expect(delivery.narration, 'Delivery @Location #5 (Urgent!)');
    });

    test('Delivery with zero quantity is allowed', () {
      final delivery = Delivery(
        coldStorageName: 'Cold Storage I',
        receiptNumber: 'R010',
        quantity: 0,
        narration: 'Zero quantity test',
        deliveryDate: testTimestamp,
      );

      expect(delivery.quantity, 0);
    });
  });
}
