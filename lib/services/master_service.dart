// 📁 lib/services/master_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MasterService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final List<String> _coldStorages = [];
  static final List<String> _products = [];
  static final List<String> _brands = [];
  static final List<String> _companies = [];

  static List<String> get coldStorages => _coldStorages;
  static List<String> get products => _products;
  static List<String> get brands => _brands;
  static List<String> get companies => _companies;

  // Load all master data from Firestore
  static Future<void> loadAllMasters() async {
    await Future.wait([
      _loadCollection('cold_storages', _coldStorages),
      _loadCollection('products', _products),
      _loadCollection('brands', _brands),
      _loadCollection('companies', _companies),
    ]);
  }

  static Future<void> _loadCollection(
    String collectionName,
    List<String> targetList,
  ) async {
    final snapshot = await _firestore.collection(collectionName).get();
    targetList.clear();
    targetList.addAll(
      snapshot.docs.map((doc) => doc['name'].toString()).toList(),
    );
  }

  static Future<void> addColdStorage(String value) async {
    if (!_coldStorages.contains(value)) {
      await _addToFirestore('cold_storages', value);
      _coldStorages.add(value);
    }
  }

  static Future<void> addProduct(String value, double weight) async {
    final lower = value.toLowerCase();
    final hasExisting = _products.any((item) => item.toLowerCase() == lower);
    if (!hasExisting) {
      await _firestore.collection('products').add({
        'name': value,
        'name_lowercase': lower,
        'weight': weight,
      });
      _products.add(value);
    }
  }

  static Future<void> addBrand(String value) async {
    if (!_brands.contains(value)) {
      await _addToFirestore('brands', value);
      _brands.add(value);
    }
  }

  static Future<void> addCompany(String value) async {
    final lower = value.toLowerCase();
    final hasExisting = _companies.any((item) => item.toLowerCase() == lower);
    if (!hasExisting) {
      await _addToFirestore('companies', value);
      _companies.add(value);
    }
  }

  static Future<void> _addToFirestore(
    String collectionName,
    String value,
  ) async {
    await _firestore.collection(collectionName).add({
      'name': value,
      'name_lowercase': value.toLowerCase(),
    });
  }
}
