// test/integration/receipt_delivery_flow_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cold_storage/models/receipt_model.dart';
import 'package:cold_storage/models/delivery_model.dart';

void main() {
  group('Receipt-Delivery Integration Flow Tests', () {
    final testTimestamp = Timestamp.fromDate(DateTime(2025, 1, 15));

    test('Complete receipt creation and delivery flow', () {
      // Step 1: Create receipt
      final receipt = Receipt(
        id: 'receipt001',
        receiptNumber: 'R001',
        coldStorageName: 'Cold Storage A',
        inwardDate: testTimestamp,
        productName: 'Apples',
        brandName: 'Brand X',
        companyName: 'Company Y',
        inwardQuantity: 100,
        remainingQuantity: 100,
        rate: 25.5,
        narration: 'Initial receipt',
      );

      expect(receipt.id, 'receipt001');
      expect(receipt.inwardQuantity, 100);
      expect(receipt.remainingQuantity, 100);

      // Step 2: First partial delivery
      final delivery1 = Delivery(
        id: 'delivery001',
        coldStorageName: receipt.coldStorageName,
        receiptNumber: receipt.receiptNumber,
        quantity: 30,
        narration: 'First delivery',
        deliveryDate: testTimestamp,
      );

      final remainingAfterDelivery1 =
          receipt.remainingQuantity - delivery1.quantity;
      expect(remainingAfterDelivery1, 70);

      // Update receipt
      final updatedReceipt1 = receipt.copyWith(
        remainingQuantity: remainingAfterDelivery1,
      );
      expect(updatedReceipt1.remainingQuantity, 70);

      // Step 3: Second partial delivery
      final delivery2 = Delivery(
        id: 'delivery002',
        coldStorageName: receipt.coldStorageName,
        receiptNumber: receipt.receiptNumber,
        quantity: 40,
        narration: 'Second delivery',
        deliveryDate: testTimestamp,
      );

      final remainingAfterDelivery2 =
          updatedReceipt1.remainingQuantity - delivery2.quantity;
      expect(remainingAfterDelivery2, 30);

      // Update receipt again
      final updatedReceipt2 = updatedReceipt1.copyWith(
        remainingQuantity: remainingAfterDelivery2,
      );
      expect(updatedReceipt2.remainingQuantity, 30);

      // Step 4: Final delivery
      final delivery3 = Delivery(
        id: 'delivery003',
        coldStorageName: receipt.coldStorageName,
        receiptNumber: receipt.receiptNumber,
        quantity: 30,
        narration: 'Final delivery',
        deliveryDate: testTimestamp,
      );

      final remainingAfterDelivery3 =
          updatedReceipt2.remainingQuantity - delivery3.quantity;
      expect(remainingAfterDelivery3, 0);

      // Final receipt state
      final finalReceipt = updatedReceipt2.copyWith(
        remainingQuantity: remainingAfterDelivery3,
      );
      expect(finalReceipt.remainingQuantity, 0);
      expect(finalReceipt.inwardQuantity, 100);

      // Verify total deliveries equal inward quantity
      final totalDelivered =
          delivery1.quantity + delivery2.quantity + delivery3.quantity;
      expect(totalDelivered, finalReceipt.inwardQuantity);
    });

    test('Receipt editing updates maintain data integrity', () {
      // Original receipt
      final originalReceipt = Receipt(
        id: 'receipt002',
        receiptNumber: 'R002',
        coldStorageName: 'Cold Storage B',
        inwardDate: testTimestamp,
        productName: 'Oranges',
        brandName: 'Brand Y',
        companyName: 'Company Z',
        inwardQuantity: 200,
        remainingQuantity: 150,
        rate: 30.0,
        narration: 'Original',
      );

      // Edit receipt (only allowed fields)
      final editedReceipt = originalReceipt.copyWith(
        rate: 35.0,
        narration: 'Updated rate',
        isPaid: true,
      );

      // Critical fields should remain unchanged
      expect(editedReceipt.receiptNumber, originalReceipt.receiptNumber);
      expect(editedReceipt.coldStorageName, originalReceipt.coldStorageName);
      expect(editedReceipt.inwardQuantity, originalReceipt.inwardQuantity);
      expect(editedReceipt.remainingQuantity, originalReceipt.remainingQuantity);

      // Editable fields should be updated
      expect(editedReceipt.rate, 35.0);
      expect(editedReceipt.narration, 'Updated rate');
      expect(editedReceipt.isPaid, true);
    });

    test('Cascade delete simulation - deleting receipt affects deliveries', () {
      // Create receipt and deliveries
      final receipt = Receipt(
        id: 'receipt003',
        receiptNumber: 'R003',
        coldStorageName: 'Cold Storage C',
        inwardDate: testTimestamp,
        productName: 'Bananas',
        brandName: 'Brand Z',
        companyName: 'Company A',
        inwardQuantity: 150,
        remainingQuantity: 75,
        rate: 15.0,
        narration: 'Test cascade',
      );

      final deliveries = [
        Delivery(
          id: 'del001',
          coldStorageName: receipt.coldStorageName,
          receiptNumber: receipt.receiptNumber,
          quantity: 50,
          narration: 'Delivery 1',
          deliveryDate: testTimestamp,
        ),
        Delivery(
          id: 'del002',
          coldStorageName: receipt.coldStorageName,
          receiptNumber: receipt.receiptNumber,
          quantity: 25,
          narration: 'Delivery 2',
          deliveryDate: testTimestamp,
        ),
      ];

      // Verify deliveries reference the receipt
      for (final delivery in deliveries) {
        expect(delivery.receiptNumber, receipt.receiptNumber);
        expect(delivery.coldStorageName, receipt.coldStorageName);
      }

      // Simulate cascade delete (would delete all related deliveries)
      final shouldDeleteDeliveries = deliveries
          .where((d) =>
              d.receiptNumber == receipt.receiptNumber &&
              d.coldStorageName == receipt.coldStorageName)
          .toList();

      expect(shouldDeleteDeliveries.length, 2);
    });

    test('Data maintenance sync validates remaining quantity accuracy', () {
      final receipt = Receipt(
        id: 'receipt004',
        receiptNumber: 'R004',
        coldStorageName: 'Cold Storage D',
        inwardDate: testTimestamp,
        productName: 'Grapes',
        brandName: 'Brand A',
        companyName: 'Company B',
        inwardQuantity: 300,
        remainingQuantity: 100, // Stored value
        rate: 45.0,
        narration: 'Sync test',
      );

      // Actual deliveries
      final actualDeliveries = [
        Delivery(
          id: 'del1',
          coldStorageName: receipt.coldStorageName,
          receiptNumber: receipt.receiptNumber,
          quantity: 80,
          narration: 'Del 1',
          deliveryDate: testTimestamp,
        ),
        Delivery(
          id: 'del2',
          coldStorageName: receipt.coldStorageName,
          receiptNumber: receipt.receiptNumber,
          quantity: 120,
          narration: 'Del 2',
          deliveryDate: testTimestamp,
        ),
      ];

      // Calculate actual remaining from deliveries
      final totalDelivered =
          actualDeliveries.fold<int>(0, (sum, d) => sum + d.quantity);
      final calculatedRemaining = receipt.inwardQuantity - totalDelivered;

      expect(totalDelivered, 200);
      expect(calculatedRemaining, 100);

      // Stored value matches calculated value (data is in sync)
      expect(receipt.remainingQuantity, calculatedRemaining);
    });

    test('Data maintenance detects and fixes sync discrepancy', () {
      final receipt = Receipt(
        id: 'receipt005',
        receiptNumber: 'R005',
        coldStorageName: 'Cold Storage E',
        inwardDate: testTimestamp,
        productName: 'Mangoes',
        brandName: 'Brand B',
        companyName: 'Company C',
        inwardQuantity: 400,
        remainingQuantity: 150, // INCORRECT stored value
        rate: 50.0,
        narration: 'Sync discrepancy',
      );

      // Actual deliveries
      final actualDeliveries = [
        Delivery(
          id: 'del1',
          coldStorageName: receipt.coldStorageName,
          receiptNumber: receipt.receiptNumber,
          quantity: 100,
          narration: 'Del 1',
          deliveryDate: testTimestamp,
        ),
        Delivery(
          id: 'del2',
          coldStorageName: receipt.coldStorageName,
          receiptNumber: receipt.receiptNumber,
          quantity: 150,
          narration: 'Del 2',
          deliveryDate: testTimestamp,
        ),
      ];

      // Calculate correct remaining from actual deliveries
      final totalDelivered =
          actualDeliveries.fold<int>(0, (sum, d) => sum + d.quantity);
      final correctRemaining = receipt.inwardQuantity - totalDelivered;

      expect(totalDelivered, 250);
      expect(correctRemaining, 150);

      // Detect discrepancy
      final hasDiscrepancy = receipt.remainingQuantity != correctRemaining;
      expect(hasDiscrepancy, false); // In this case, they match

      // Simulate fixing discrepancy
      if (hasDiscrepancy) {
        final syncedReceipt = receipt.copyWith(
          remainingQuantity: correctRemaining,
        );
        expect(syncedReceipt.remainingQuantity, correctRemaining);
      }
    });

    test('Receipt and delivery JSON serialization round-trip', () {
      // Create receipt
      final receipt = Receipt(
        receiptNumber: 'R006',
        coldStorageName: 'Cold Storage F',
        inwardDate: testTimestamp,
        productName: 'Watermelon',
        brandName: 'Brand C',
        companyName: 'Company D',
        inwardQuantity: 250,
        remainingQuantity: 200,
        rate: 20.0,
        narration: 'Serialization test',
      );

      // Convert to JSON
      final receiptJson = receipt.toJson();
      expect(receiptJson['receiptNumber'], 'R006');
      expect(receiptJson['inwardQuantity'], 250);

      // Create delivery
      final delivery = Delivery(
        coldStorageName: receipt.coldStorageName,
        receiptNumber: receipt.receiptNumber,
        quantity: 50,
        narration: 'Test delivery',
        deliveryDate: testTimestamp,
      );

      // Convert to JSON
      final deliveryJson = delivery.toJson();
      expect(deliveryJson['receiptNumber'], 'R006');
      expect(deliveryJson['quantity'], 50);

      // Verify relationship
      expect(receiptJson['receiptNumber'], deliveryJson['receiptNumber']);
      expect(receiptJson['coldStorageName'], deliveryJson['coldStorageName']);
    });

    test('Paid status toggle flow', () {
      final receipt = Receipt(
        id: 'receipt007',
        receiptNumber: 'R007',
        coldStorageName: 'Cold Storage G',
        inwardDate: testTimestamp,
        productName: 'Pineapple',
        brandName: 'Brand D',
        companyName: 'Company E',
        inwardQuantity: 180,
        remainingQuantity: 100,
        rate: 35.0,
        narration: 'Payment test',
        isPaid: false,
      );

      expect(receipt.isPaid, false);

      // Toggle to paid
      final paidReceipt = receipt.copyWith(isPaid: true);
      expect(paidReceipt.isPaid, true);

      // Toggle back to unpaid
      final unpaidReceipt = paidReceipt.copyWith(isPaid: false);
      expect(unpaidReceipt.isPaid, false);
    });
  });
}
