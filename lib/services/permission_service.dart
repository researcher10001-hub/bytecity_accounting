import '../models/user_model.dart';
import '../models/account_model.dart';
import '../models/transaction_model.dart';

class PermissionService {
  // Singleton pattern
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Check if user can view a specific account
  bool canViewAccount(User user, Account account) {
    // 1. Admin Global access
    if (user.isAdmin) return true;

    // 2. Roles with implicit full access
    if (user.isManagement) return true;
    if (user.isViewer) return true;

    // 3. Ownership or Group Access (Applies to BOA, etc)
    if (account.owners.contains(user.email)) return true;
    for (var groupId in user.groupIds) {
      if (account.groupIds.contains(groupId)) return true;
    }

    return false;
  }

  /// Check if user can EDIT a specific account (Update details, owners, etc)
  /// Note: This is different from "Entering Transactions"
  bool canEditAccountDetails(User user, Account account) {
    if (user.isAdmin) return true;
    return false; // Only Admin can edit Account Definitions
  }

  /// Check if user can Enter Transactions for this account
  bool canEnterTransaction(User user, Account account) {
    // 1. Admin always has access
    if (user.isAdmin) return true;

    if (user.isViewer) return false;

    // 2. Management Access
    if (user.isManagement) return true;

    // 3. Ownership or Group Access
    if (account.owners.contains(user.email)) return true;
    for (var groupId in user.groupIds) {
      if (account.groupIds.contains(groupId)) return true;
    }

    return false;
  }

  /// Check if user can VIEW a specific transaction
  bool canViewTransaction(User user, TransactionModel transaction) {
    // 1. Admin always has View/Audit access
    if (user.isAdmin) return true;

    if (user.isManagement) return true; // Management sees all
    if (user.isViewer) return true; // Viewers see all

    // 2. Creator Check
    if (transaction.createdBy == user.email) return true;

    // 3. Account Ownership Logic (Simplified)
    // If strict checking is required, we need the Account object.
    // For now, if not Admin/Mgmt/Viewer and not Creator, deny.
    // (This implies BOA only sees their own entries unless we do a complex lookup)

    return false;
  }

  /// Check if user can View Account Balance
  bool canViewBalance(User user) {
    if (user.isBusinessOperationsAssociate) {
      return false; // HIDDEN for BOA
    }
    return true; // Visible for Admin, Management, Viewer
  }

  /// Check if user can Access System Settings
  bool canAccessSettings(User user) {
    return user.isAdmin;
  }

  /// Check if user can View All Reports
  bool canViewReports(User user) {
    if (user.isBusinessOperationsAssociate) return false;
    return true; // Admin, Management, Viewer
  }
}
