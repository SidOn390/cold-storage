// 📁 lib/services/master_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Reactive service for managing master data with automatic Firestore sync.
///
/// This service maintains real-time synchronized lists of master data
/// (cold storages, products, brands, companies) by listening to Firestore
/// changes. Unlike the previous static implementation, this ensures data
/// consistency across all parts of the app automatically.
///
/// Usage:
/// ```dart
/// // Access current cached data (synchronous)
/// final storages = MasterService.coldStorages;
///
/// // Or use the singleton instance
/// final storages = MasterService.instance.coldStorages;
///
/// // Listen to reactive updates
/// MasterService.instance.coldStoragesStream.listen((list) {
///   // Handle updates
/// });
/// ```
class MasterService {
  MasterService._();

  static final MasterService _instance = MasterService._();
  static MasterService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream controllers for reactive updates
  final _coldStoragesController = StreamController<List<String>>.broadcast();
  final _productsController = StreamController<List<String>>.broadcast();
  final _brandsController = StreamController<List<String>>.broadcast();
  final _companiesController = StreamController<List<String>>.broadcast();

  // Current cached values
  static List<String> _coldStorages = [];
  static List<String> _products = [];
  static List<String> _brands = [];
  static List<String> _companies = [];

  // Firestore listeners
  StreamSubscription<QuerySnapshot>? _coldStoragesListener;
  StreamSubscription<QuerySnapshot>? _productsListener;
  StreamSubscription<QuerySnapshot>? _brandsListener;
  StreamSubscription<QuerySnapshot>? _companiesListener;

  bool _isInitialized = false;

  /// Synchronous access to current cached data (static API for backward compatibility)
  static List<String> get coldStorages => List.unmodifiable(_coldStorages);
  static List<String> get products => List.unmodifiable(_products);
  static List<String> get brands => List.unmodifiable(_brands);
  static List<String> get companies => List.unmodifiable(_companies);

  /// Reactive streams for listening to data changes
  Stream<List<String>> get coldStoragesStream => _coldStoragesController.stream;
  Stream<List<String>> get productsStream => _productsController.stream;
  Stream<List<String>> get brandsStream => _brandsController.stream;
  Stream<List<String>> get companiesStream => _companiesController.stream;

  /// Initialize the service and start listening to Firestore changes.
  /// This should be called once at app startup.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ MasterService already initialized');
      return;
    }

    try {
      // Set up real-time listeners
      _coldStoragesListener = _firestore
          .collection('cold_storages')
          .orderBy('name')
          .snapshots()
          .listen((snapshot) {
        _coldStorages = snapshot.docs
            .map((doc) => doc['name'] as String)
            .toList();
        _coldStoragesController.add(_coldStorages);
        debugPrint('✅ Cold storages updated: ${_coldStorages.length} items');
      });

      _productsListener = _firestore
          .collection('products')
          .orderBy('name')
          .snapshots()
          .listen((snapshot) {
        _products = snapshot.docs
            .map((doc) => doc['name'] as String)
            .toList();
        _productsController.add(_products);
        debugPrint('✅ Products updated: ${_products.length} items');
      });

      _brandsListener = _firestore
          .collection('brands')
          .orderBy('name')
          .snapshots()
          .listen((snapshot) {
        _brands = snapshot.docs
            .map((doc) => doc['name'] as String)
            .toList();
        _brandsController.add(_brands);
        debugPrint('✅ Brands updated: ${_brands.length} items');
      });

      _companiesListener = _firestore
          .collection('companies')
          .orderBy('name')
          .snapshots()
          .listen((snapshot) {
        _companies = snapshot.docs
            .map((doc) => doc['name'] as String)
            .toList();
        _companiesController.add(_companies);
        debugPrint('✅ Companies updated: ${_companies.length} items');
      });

      _isInitialized = true;
      debugPrint('✅ MasterService initialized with real-time sync');
    } catch (e, st) {
      debugPrint('❌ MasterService initialization failed: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Legacy method for backward compatibility.
  /// In the new implementation, this is handled automatically by listeners.
  @Deprecated('Data is now loaded automatically via real-time listeners')
  static Future<void> loadAllMasters() async {
    await instance.initialize();
  }

  /// Add a new cold storage (updates Firestore, listener will update cache)
  static Future<void> addColdStorage(String value) async {
    final trimmed = value.trim();
    if (_coldStorages.contains(trimmed)) {
      debugPrint('⚠️ Cold storage "$trimmed" already exists');
      return;
    }
    await instance._addToFirestore('cold_storages', trimmed);
  }

  /// Add a new product (updates Firestore, listener will update cache)
  static Future<void> addProduct(String value, double weight) async {
    final trimmed = value.trim();
    final lower = trimmed.toLowerCase();
    final hasExisting = _products.any((item) => item.toLowerCase() == lower);
    if (hasExisting) {
      debugPrint('⚠️ Product "$trimmed" already exists');
      return;
    }
    await instance._firestore.collection('products').add({
      'name': trimmed,
      'name_lowercase': lower,
      'weight': weight,
    });
  }

  /// Add a new brand (updates Firestore, listener will update cache)
  static Future<void> addBrand(String value) async {
    final trimmed = value.trim();
    if (_brands.contains(trimmed)) {
      debugPrint('⚠️ Brand "$trimmed" already exists');
      return;
    }
    await instance._addToFirestore('brands', trimmed);
  }

  /// Add a new company (updates Firestore, listener will update cache)
  static Future<void> addCompany(String value) async {
    final trimmed = value.trim();
    final lower = trimmed.toLowerCase();
    final hasExisting = _companies.any((item) => item.toLowerCase() == lower);
    if (hasExisting) {
      debugPrint('⚠️ Company "$trimmed" already exists');
      return;
    }
    await instance._addToFirestore('companies', trimmed);
  }

  Future<void> _addToFirestore(String collectionName, String value) async {
    await _firestore.collection(collectionName).add({
      'name': value,
      'name_lowercase': value.toLowerCase(),
    });
  }

  /// Dispose of all listeners and controllers (call on app shutdown if needed)
  void dispose() {
    _coldStoragesListener?.cancel();
    _productsListener?.cancel();
    _brandsListener?.cancel();
    _companiesListener?.cancel();

    _coldStoragesController.close();
    _productsController.close();
    _brandsController.close();
    _companiesController.close();

    _isInitialized = false;
    debugPrint('🔌 MasterService disposed');
  }
}
