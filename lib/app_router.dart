// File: lib/app_router.dart

import 'package:cold_storage/models/delivery_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/receipt_entry/receipt_entry_screen.dart';
import 'screens/receipt_entry/receipt_list_screen.dart';
import 'screens/delivery_entry/delivery_entry_screen.dart';
import 'screens/delivery_entry/delivery_history_screen.dart';
import 'screens/billing_checker/billing_checker_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/masters/masters_menu_screen.dart';
import 'screens/masters/cold_storage_master_screen.dart';
import 'screens/masters/product_master_screen.dart';
import 'screens/masters/brand_master_screen.dart';
import 'screens/masters/company_master_screen.dart';
import 'screens/masters/rent_rate_master_screen.dart';
// import 'screens/billing/rent_bill_screen.dart'; // No longer needed - using Billing Checker
import 'screens/admin/data_maintenance_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/tools/backup_encryption_tools_screen.dart';
import 'screens/setup/initial_setup_screen.dart';
import 'package:cold_storage/models/receipt_model.dart';

class AppRouter {
  static const authGate = '/';
  static const dashboard = '/dashboard';
  static const receiptEntry = '/receipt-entry';
  static const receiptList = '/receipt-list';
  static const deliveryEntry = '/delivery-entry';
  static const deliveryHistory = '/delivery-history';
  static const billingChecker = '/billing-checker';
  static const reports = '/reports';
  static const mastersMenu = '/masters';
  static const coldStorageMaster = '/masters/cold-storages';
  static const productTypeMaster = '/masters/product-types';
  static const brandMaster = '/masters/brands';
  static const companyMaster = '/masters/companies';
  static const rentRateMaster = '/masters/rent-rates';
  // static const rentBill = '/billing/rent-bill'; // Replaced by enhanced Billing Checker
  static const dataMaintenance = '/admin/data-maintenance';
  static const userManagement = '/admin/user-management';
  static const backupEncryptionTools = '/tools/backup-encryption';
  static const initialSetup = '/setup/initial';
  static const String billingDetail = '/billingDetail';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final isAuth = FirebaseAuth.instance.currentUser != null;

    Widget screenBuilder(Widget w) => isAuth ? w : const AuthGate();

    switch (settings.name) {
      case authGate:
        return MaterialPageRoute(builder: (_) => const AuthGate());
      case dashboard:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const DashboardScreen()),
        );
      case receiptEntry:
        // MODIFIED: Check if a Receipt object is being passed as an argument
        final receipt = settings.arguments as Receipt?;
        return MaterialPageRoute(
          builder: (_) => screenBuilder(ReceiptEntryScreen(receipt: receipt)),
        );
      case receiptList:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const ReceiptListScreen()),
        );
      case deliveryEntry:
        final delivery = settings.arguments as Delivery?; // Can be null
        return MaterialPageRoute(
          builder: (_) => DeliveryEntryScreen(delivery: delivery),
        );
      case deliveryHistory:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const DeliveryHistoryScreen()),
        );
      case billingChecker:
        final receipt = settings.arguments as Receipt?;
        return MaterialPageRoute(
          builder: (_) => screenBuilder(BillingCheckerScreen(initialDetailReceipt: receipt)),
        );
      case reports:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const ReportsScreen()),
        );
      case mastersMenu:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const MastersMenuScreen()),
        );
      case coldStorageMaster:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const ColdStorageMasterScreen()),
        );
      case productTypeMaster:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const ProductMasterScreen()),
        );
      case brandMaster:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const BrandMasterScreen()),
        );
      case companyMaster:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const CompanyMasterScreen()),
        );
      case rentRateMaster:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const RentRateMasterScreen()),
        );
      // case rentBill: // Replaced by enhanced Billing Checker
      //   return MaterialPageRoute(
      //     builder: (_) => screenBuilder(const RentBillScreen()),
      //   );
      case dataMaintenance:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const DataMaintenanceScreen()),
        );
      case userManagement:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const UserManagementScreen()),
        );
      case backupEncryptionTools:
        return MaterialPageRoute(
          builder: (_) => screenBuilder(const BackupEncryptionToolsScreen()),
        );
      case initialSetup:
        return MaterialPageRoute(
          builder: (_) => const InitialSetupScreen(),
        );
      default:
        return MaterialPageRoute(builder: (_) => const AuthGate());
    }
  }
}
