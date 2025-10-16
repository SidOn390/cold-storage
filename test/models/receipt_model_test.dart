// test/models/receipt_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cold_storage/models/receipt_model.dart';

void main() {
  group('Receipt Model Tests', () {
    final testTimestamp = Timestamp.fromDate(DateTime(2025, 1, 15));
    final testCreatedAt = Timestamp.fromDate(DateTime(2025, 1, 10));

    test('Receipt constructor creates instance with required fields', () {
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
        narration: 'Test narration',
      );

      expect(receipt.receiptNumber, 'R001');
      expect(receipt.coldStorageName, 'Cold Storage A');
      expect(receipt.inwardDate, testTimestamp);
      expect(receipt.productName, 'Apples');
      expect(receipt.brandName, 'Brand X');
      expect(receipt.companyName, 'Company Y');
      expect(receipt.inwardQuantity, 100);
      expect(receipt.remainingQuantity, 80);
      expect(receipt.rate, 25.5);
      expect(receipt.narration, 'Test narration');
      expect(receipt.isPaid, false); // default value
      expect(receipt.status, 'Active'); // default value
    });

    test('Receipt constructor accepts optional fields', () {
      final receipt = Receipt(
        id: 'receipt123',
        receiptNumber: 'R002',
        coldStorageName: 'Cold Storage B',
        inwardDate: testTimestamp,
        productName: 'Oranges',
        brandName: 'Brand Z',
        companyName: 'Company X',
        inwardQuantity: 200,
        remainingQuantity: 150,
        rate: 30.0,
        narration: 'Optional fields test',
        isPaid: true,
        status: 'Completed',
        createdAt: testCreatedAt,
      );

      expect(receipt.id, 'receipt123');
      expect(receipt.isPaid, true);
      expect(receipt.status, 'Completed');
      expect(receipt.createdAt, testCreatedAt);
    });

    test('toJson converts Receipt to Map correctly', () {
      final receipt = Receipt(
        receiptNumber: 'R003',
        coldStorageName: 'Cold Storage C',
        inwardDate: testTimestamp,
        productName: 'Bananas',
        brandName: 'Brand A',
        companyName: 'Company B',
        inwardQuantity: 300,
        remainingQuantity: 250,
        rate: 15.75,
        narration: 'JSON test',
        isPaid: true,
        status: 'Active',
        createdAt: testCreatedAt,
      );

      final json = receipt.toJson();

      expect(json['receiptNumber'], 'R003');
      expect(json['coldStorageName'], 'Cold Storage C');
      expect(json['inwardDate'], testTimestamp);
      expect(json['productName'], 'Bananas');
      expect(json['brandName'], 'Brand A');
      expect(json['companyName'], 'Company B');
      expect(json['inwardQuantity'], 300);
      expect(json['remainingQuantity'], 250);
      expect(json['rate'], 15.75);
      expect(json['narration'], 'JSON test');
      expect(json['isPaid'], true);
      expect(json['status'], 'Active');
      expect(json['createdAt'], testCreatedAt);
    });

    test('toJson uses FieldValue.serverTimestamp when createdAt is null', () {
      final receipt = Receipt(
        receiptNumber: 'R004',
        coldStorageName: 'Cold Storage D',
        inwardDate: testTimestamp,
        productName: 'Grapes',
        brandName: 'Brand B',
        companyName: 'Company C',
        inwardQuantity: 50,
        remainingQuantity: 40,
        rate: 45.0,
        narration: 'Server timestamp test',
      );

      final json = receipt.toJson();

      // createdAt should be FieldValue.serverTimestamp() when null
      expect(json['createdAt'], isA<FieldValue>());
    });

    test('copyWith creates new instance with updated fields', () {
      final original = Receipt(
        id: 'receipt456',
        receiptNumber: 'R005',
        coldStorageName: 'Cold Storage E',
        inwardDate: testTimestamp,
        productName: 'Mangoes',
        brandName: 'Brand C',
        companyName: 'Company D',
        inwardQuantity: 150,
        remainingQuantity: 100,
        rate: 50.0,
        narration: 'Original',
        isPaid: false,
        status: 'Active',
      );

      final updated = original.copyWith(
        remainingQuantity: 75,
        isPaid: true,
        narration: 'Updated narration',
      );

      // Updated fields should change
      expect(updated.remainingQuantity, 75);
      expect(updated.isPaid, true);
      expect(updated.narration, 'Updated narration');

      // Other fields should remain the same
      expect(updated.id, 'receipt456');
      expect(updated.receiptNumber, 'R005');
      expect(updated.coldStorageName, 'Cold Storage E');
      expect(updated.productName, 'Mangoes');
      expect(updated.inwardQuantity, 150);
      expect(updated.rate, 50.0);
      expect(updated.status, 'Active');
    });

    test('copyWith without parameters returns identical copy', () {
      final original = Receipt(
        id: 'receipt789',
        receiptNumber: 'R006',
        coldStorageName: 'Cold Storage F',
        inwardDate: testTimestamp,
        productName: 'Watermelon',
        brandName: 'Brand D',
        companyName: 'Company E',
        inwardQuantity: 75,
        remainingQuantity: 60,
        rate: 20.0,
        narration: 'No changes',
        createdAt: testCreatedAt,
      );

      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.receiptNumber, original.receiptNumber);
      expect(copy.coldStorageName, original.coldStorageName);
      expect(copy.inwardDate, original.inwardDate);
      expect(copy.productName, original.productName);
      expect(copy.brandName, original.brandName);
      expect(copy.companyName, original.companyName);
      expect(copy.inwardQuantity, original.inwardQuantity);
      expect(copy.remainingQuantity, original.remainingQuantity);
      expect(copy.rate, original.rate);
      expect(copy.narration, original.narration);
      expect(copy.isPaid, original.isPaid);
      expect(copy.status, original.status);
      expect(copy.createdAt, original.createdAt);
    });

    test('Rate field accepts double values correctly', () {
      final receipt = Receipt(
        receiptNumber: 'R007',
        coldStorageName: 'Cold Storage G',
        inwardDate: testTimestamp,
        productName: 'Pineapple',
        brandName: 'Brand E',
        companyName: 'Company F',
        inwardQuantity: 120,
        remainingQuantity: 100,
        rate: 33.99,
        narration: 'Rate precision test',
      );

      expect(receipt.rate, 33.99);
      expect(receipt.rate, isA<double>());
    });

    test('Quantity fields accept integer values correctly', () {
      final receipt = Receipt(
        receiptNumber: 'R008',
        coldStorageName: 'Cold Storage H',
        inwardDate: testTimestamp,
        productName: 'Strawberries',
        brandName: 'Brand F',
        companyName: 'Company G',
        inwardQuantity: 500,
        remainingQuantity: 350,
        rate: 75.5,
        narration: 'Quantity test',
      );

      expect(receipt.inwardQuantity, 500);
      expect(receipt.remainingQuantity, 350);
      expect(receipt.inwardQuantity, isA<int>());
      expect(receipt.remainingQuantity, isA<int>());
    });

    test('Receipt handles empty narration', () {
      final receipt = Receipt(
        receiptNumber: 'R009',
        coldStorageName: 'Cold Storage I',
        inwardDate: testTimestamp,
        productName: 'Blueberries',
        brandName: 'Brand G',
        companyName: 'Company H',
        inwardQuantity: 80,
        remainingQuantity: 70,
        rate: 90.0,
        narration: '',
      );

      expect(receipt.narration, '');
      expect(receipt.narration.isEmpty, true);
    });
  });
}
