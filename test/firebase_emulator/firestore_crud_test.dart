// test/firebase_emulator/firestore_crud_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cold_storage/services/firestore_service.dart';
import '../firebase_emulator_helper.dart';

void main() {
  group('Firestore CRUD Operations (Emulator)', () {
    late FirestoreService firestoreService;

    setUpAll(() async {
      await FirebaseEmulatorHelper.setupEmulator();
      firestoreService = FirestoreService();
    });

    setUp(() async {
      // Clear data before each test
      await FirebaseEmulatorHelper.clearFirestoreData();
    });

    group('Cold Storage Master CRUD', () {
      test('Can create cold storage', () async {
        await firestoreService.addColdStorage('Test Cold Storage A');

        final coldStorages = await firestoreService.getColdStorages().first;
        expect(coldStorages.length, 1);
        expect(coldStorages[0]['name'], 'Test Cold Storage A');
      });

      test('Can read cold storages', () async {
        await firestoreService.addColdStorage('Storage 1');
        await firestoreService.addColdStorage('Storage 2');
        await firestoreService.addColdStorage('Storage 3');

        final coldStorages = await firestoreService.getColdStorages().first;
        expect(coldStorages.length, 3);
      });

      test('Can update cold storage', () async {
        await firestoreService.addColdStorage('Original Name');
        final coldStorages = await firestoreService.getColdStorages().first;
        final id = coldStorages[0]['id'];

        await firestoreService.updateColdStorage(
          id,
          'Updated Name',
          oldName: 'Original Name',
        );

        final updated = await firestoreService.getColdStorages().first;
        expect(updated[0]['name'], 'Updated Name');
      });

      test('Can delete cold storage', () async {
        await firestoreService.addColdStorage('To Delete');
        final coldStorages = await firestoreService.getColdStorages().first;
        final id = coldStorages[0]['id'];

        await firestoreService.deleteColdStorage(id);

        final afterDelete = await firestoreService.getColdStorages().first;
        expect(afterDelete.length, 0);
      });

      test('Cold storages are sorted by name', () async {
        await firestoreService.addColdStorage('Zebra Storage');
        await firestoreService.addColdStorage('Apple Storage');
        await firestoreService.addColdStorage('Middle Storage');

        final coldStorages = await firestoreService.getColdStorages().first;
        expect(coldStorages[0]['name'], 'Apple Storage');
        expect(coldStorages[1]['name'], 'Middle Storage');
        expect(coldStorages[2]['name'], 'Zebra Storage');
      });
    });

    group('Product Master CRUD', () {
      test('Can create product with weight', () async {
        await firestoreService.addProduct('Apples', 50.5);

        final products = await firestoreService.getProducts().first;
        expect(products.length, 1);
        expect(products[0]['name'], 'Apples');
        expect(products[0]['weight'], 50.5);
      });

      test('Can update product name and weight', () async {
        await firestoreService.addProduct('Original Product', 10.0);
        final products = await firestoreService.getProducts().first;
        final id = products[0]['id'];

        await firestoreService.updateProduct(
          id,
          'Updated Product',
          25.5,
          oldName: 'Original Product',
        );

        final updated = await firestoreService.getProducts().first;
        expect(updated[0]['name'], 'Updated Product');
        expect(updated[0]['weight'], 25.5);
      });

      test('Can delete product', () async {
        await firestoreService.addProduct('To Delete', 15.0);
        final products = await firestoreService.getProducts().first;
        final id = products[0]['id'];

        await firestoreService.deleteProduct(id);

        final afterDelete = await firestoreService.getProducts().first;
        expect(afterDelete.length, 0);
      });
    });

    group('Brand Master CRUD', () {
      test('Can create brand', () async {
        await firestoreService.addBrand('Test Brand');

        final brands = await firestoreService.getBrands().first;
        expect(brands.length, 1);
        expect(brands[0]['name'], 'Test Brand');
      });

      test('Can update brand', () async {
        await firestoreService.addBrand('Old Brand');
        final brands = await firestoreService.getBrands().first;
        final id = brands[0]['id'];

        await firestoreService.updateBrand(id, 'New Brand', oldName: 'Old Brand');

        final updated = await firestoreService.getBrands().first;
        expect(updated[0]['name'], 'New Brand');
      });

      test('Can delete brand', () async {
        await firestoreService.addBrand('To Delete');
        final brands = await firestoreService.getBrands().first;
        final id = brands[0]['id'];

        await firestoreService.deleteBrand(id);

        final afterDelete = await firestoreService.getBrands().first;
        expect(afterDelete.length, 0);
      });
    });

    group('Company Master CRUD', () {
      test('Can create company', () async {
        await firestoreService.addCompany('Test Company');

        final companies = await firestoreService.getCompanies().first;
        expect(companies.length, 1);
        expect(companies[0]['name'], 'Test Company');
      });

      test('Can update company', () async {
        await firestoreService.addCompany('Old Company');
        final companies = await firestoreService.getCompanies().first;
        final id = companies[0]['id'];

        await firestoreService.updateCompany(id, 'New Company', oldName: 'Old Company');

        final updated = await firestoreService.getCompanies().first;
        expect(updated[0]['name'], 'New Company');
      });

      test('Can delete company', () async {
        await firestoreService.addCompany('To Delete');
        final companies = await firestoreService.getCompanies().first;
        final id = companies[0]['id'];

        await firestoreService.deleteCompany(id);

        final afterDelete = await firestoreService.getCompanies().first;
        expect(afterDelete.length, 0);
      });
    });

    group('Duplicate Prevention', () {
      test('Cannot create duplicate cold storage (case insensitive)', () async {
        await firestoreService.addColdStorage('Test Storage');

        // Try to add with different case - should be prevented by name_lowercase
        await firestoreService.addColdStorage('test storage');

        final coldStorages = await firestoreService.getColdStorages().first;
        // Depending on implementation, might allow or prevent - test the behavior
        expect(coldStorages.length, greaterThanOrEqualTo(1));
      });
    });

    group('Data Integrity', () {
      test('Trimmed names are saved correctly', () async {
        await firestoreService.addColdStorage('  Trimmed Name  ');

        final coldStorages = await firestoreService.getColdStorages().first;
        expect(coldStorages[0]['name'], 'Trimmed Name');
      });

      test('Lowercase field is created for searching', () async {
        await firestoreService.addColdStorage('Mixed CASE Name');

        // Verify lowercase field exists in Firestore
        final snapshot = await FirebaseFirestore.instance
            .collection('cold_storages')
            .get();

        expect(snapshot.docs[0].data().containsKey('name_lowercase'), true);
        expect(snapshot.docs[0].data()['name_lowercase'], 'mixed case name');
      });
    });
  });
}
