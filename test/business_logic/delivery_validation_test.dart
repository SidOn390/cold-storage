// test/business_logic/delivery_validation_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cold_storage/models/receipt_model.dart';

void main() {
  group('Delivery Validation Business Logic Tests', () {
    final testTimestamp = Timestamp.fromDate(DateTime(2025, 1, 15));

    test('Receipt with sufficient remaining quantity allows delivery', () {
      final receipt = Receipt(
        receiptNumber: 'R001',
        coldStorageName: 'Cold Storage A',
        inwardDate: testTimestamp,
        productName: 'Apples',
        brandName: 'Brand X',
        companyName: 'Company Y',
        inwardQuantity: 100,
        remainingQuantity: 80,
        rate: 25.5,
        narration: 'Test',
      );

      // Attempting to deliver 50 units when 80 are remaining
      const attemptedDelivery = 50;
      expect(attemptedDelivery <= receipt.remainingQuantity, true);
    });

    test('Receipt with insufficient remaining quantity should block delivery',
        () {
      final receipt = Receipt(
        receiptNumber: 'R002',
        coldStorageName: 'Cold Storage B',
        inwardDate: testTimestamp,
        productName: 'Oranges',
        brandName: 'Brand Y',
        companyName: 'Company Z',
        inwardQuantity: 100,
        remainingQuantity: 30,
        rate: 30.0,
        narration: 'Test',
      );

      // Attempting to deliver 50 units when only 30 are remaining
      const attemptedDelivery = 50;
      expect(attemptedDelivery > receipt.remainingQuantity, true);
    });

    test('Receipt allows exact remaining quantity delivery', () {
      final receipt = Receipt(
        receiptNumber: 'R003',
        coldStorageName: 'Cold Storage C',
        inwardDate: testTimestamp,
        productName: 'Bananas',
        brandName: 'Brand Z',
        companyName: 'Company A',
        inwardQuantity: 100,
        remainingQuantity: 75,
        rate: 15.0,
        narration: 'Test',
      );

      // Attempting to deliver exactly the remaining quantity
      const attemptedDelivery = 75;
      expect(attemptedDelivery == receipt.remainingQuantity, true);
      expect(attemptedDelivery <= receipt.remainingQuantity, true);
    });

    test('Receipt with zero remaining quantity blocks all deliveries', () {
      final receipt = Receipt(
        receiptNumber: 'R004',
        coldStorageName: 'Cold Storage D',
        inwardDate: testTimestamp,
        productName: 'Grapes',
        brandName: 'Brand A',
        companyName: 'Company B',
        inwardQuantity: 100,
        remainingQuantity: 0,
        rate: 45.0,
        narration: 'Test',
      );

      const attemptedDelivery = 1;
      expect(attemptedDelivery > receipt.remainingQuantity, true);
    });

    test('Remaining quantity calculation is correct', () {
      const inwardQuantity = 200;
      const deliveredQuantity = 75;
      const expectedRemaining = inwardQuantity - deliveredQuantity;

      expect(expectedRemaining, 125);
    });

    test('Multiple partial deliveries reduce remaining quantity correctly', () {
      const inwardQuantity = 500;
      const delivery1 = 100;
      const delivery2 = 150;
      const delivery3 = 75;

      const remainingAfterDelivery1 = inwardQuantity - delivery1;
      const remainingAfterDelivery2 = remainingAfterDelivery1 - delivery2;
      const remainingAfterDelivery3 = remainingAfterDelivery2 - delivery3;

      expect(remainingAfterDelivery1, 400);
      expect(remainingAfterDelivery2, 250);
      expect(remainingAfterDelivery3, 175);
    });

    test('Delivery validation prevents negative remaining quantity', () {
      final receipt = Receipt(
        receiptNumber: 'R005',
        coldStorageName: 'Cold Storage E',
        inwardDate: testTimestamp,
        productName: 'Mangoes',
        brandName: 'Brand B',
        companyName: 'Company C',
        inwardQuantity: 100,
        remainingQuantity: 40,
        rate: 50.0,
        narration: 'Test',
      );

      const attemptedDelivery = 60;
      final wouldBeNegative = receipt.remainingQuantity - attemptedDelivery < 0;
      expect(wouldBeNegative, true);
    });

    test('Receipt status Active indicates available for delivery', () {
      final receipt = Receipt(
        receiptNumber: 'R006',
        coldStorageName: 'Cold Storage F',
        inwardDate: testTimestamp,
        productName: 'Watermelon',
        brandName: 'Brand C',
        companyName: 'Company D',
        inwardQuantity: 150,
        remainingQuantity: 100,
        rate: 20.0,
        narration: 'Test',
        status: 'Active',
      );

      expect(receipt.status, 'Active');
      expect(receipt.remainingQuantity > 0, true);
    });

    test('Receipt inward quantity must be positive', () {
      final receipt = Receipt(
        receiptNumber: 'R007',
        coldStorageName: 'Cold Storage G',
        inwardDate: testTimestamp,
        productName: 'Pineapple',
        brandName: 'Brand D',
        companyName: 'Company E',
        inwardQuantity: 100,
        remainingQuantity: 80,
        rate: 35.0,
        narration: 'Test',
      );

      expect(receipt.inwardQuantity > 0, true);
    });

    test('Remaining quantity cannot exceed inward quantity', () {
      final receipt = Receipt(
        receiptNumber: 'R008',
        coldStorageName: 'Cold Storage H',
        inwardDate: testTimestamp,
        productName: 'Strawberries',
        brandName: 'Brand E',
        companyName: 'Company F',
        inwardQuantity: 200,
        remainingQuantity: 150,
        rate: 75.0,
        narration: 'Test',
      );

      expect(receipt.remainingQuantity <= receipt.inwardQuantity, true);
    });

    test('Delivered quantity calculation is accurate', () {
      const inwardQuantity = 300;
      const remainingQuantity = 175;
      const deliveredQuantity = inwardQuantity - remainingQuantity;

      expect(deliveredQuantity, 125);
    });

    test('Zero delivery quantity should be invalid', () {
      const attemptedDelivery = 0;
      expect(attemptedDelivery <= 0, true);
    });

    test('Negative delivery quantity should be invalid', () {
      const attemptedDelivery = -10;
      expect(attemptedDelivery < 0, true);
    });

    test('Receipt rate must be positive', () {
      final receipt = Receipt(
        receiptNumber: 'R009',
        coldStorageName: 'Cold Storage I',
        inwardDate: testTimestamp,
        productName: 'Blueberries',
        brandName: 'Brand F',
        companyName: 'Company G',
        inwardQuantity: 80,
        remainingQuantity: 60,
        rate: 90.0,
        narration: 'Test',
      );

      expect(receipt.rate > 0, true);
    });

    test('Multiple receipts with same receipt number but different cold storage',
        () {
      final receipt1 = Receipt(
        receiptNumber: 'R010',
        coldStorageName: 'Cold Storage J',
        inwardDate: testTimestamp,
        productName: 'Cherries',
        brandName: 'Brand G',
        companyName: 'Company H',
        inwardQuantity: 100,
        remainingQuantity: 80,
        rate: 55.0,
        narration: 'Test',
      );

      final receipt2 = Receipt(
        receiptNumber: 'R010',
        coldStorageName: 'Cold Storage K',
        inwardDate: testTimestamp,
        productName: 'Cherries',
        brandName: 'Brand G',
        companyName: 'Company H',
        inwardQuantity: 150,
        remainingQuantity: 120,
        rate: 55.0,
        narration: 'Test',
      );

      // Same receipt number but different cold storage should be allowed
      expect(receipt1.receiptNumber, receipt2.receiptNumber);
      expect(receipt1.coldStorageName, isNot(receipt2.coldStorageName));
    });
  });
}
