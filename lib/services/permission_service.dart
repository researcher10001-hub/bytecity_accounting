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
    if (isOwner(user, account)) return true;
    if (isGroupMember(user, account)) return true;

    return false;
  }

  /// Check if user is an OWNER of the account
  bool isOwner(User user, Account account) {
    return account.owners.any(
      (ownerEmail) =>
          ownerEmail.trim().toLowerCase() == user.email.trim().toLowerCase(),
    );
  }

  /// Check if user has GROUP access to the account (not ownership)
  bool isGroupMember(User user, Account account) {
    for (var groupId in user.groupIds) {
      if (account.groupIds.contains(groupId)) return true;
    }
    return false;
  }

  /// Check if user can VIEW a specific transaction
  /// Rules:
  /// - Admin/Management/Viewer: see all
  /// - Owner of any involved account: see all entries for that account
  /// - Group member (not owner): only see if they CREATED the transaction
  bool canViewTransaction(User user, TransactionModel transaction) {
    // 1. Admin always has View/Audit access
    if (user.isAdmin) return true;

    if (user.isManagement) return true; // Management sees all
    if (user.isViewer) return true; // Viewers see all

    // 2. Branch Manager Check - see all within their own branch
    if (user.isBranchManager &&
        transaction.branch.trim().toLowerCase() ==
            user.branch.trim().toLowerCase()) {
      return true;
    }

    // 3. Creator Check — user always sees their own transactions
    final currentUserEmail = user.email.trim().toLowerCase();
    if (transaction.createdBy.trim().toLowerCase() == currentUserEmail) {
      return true;
    }

    // 3. Account Ownership Logic
    // If user OWNS any account involved in this transaction, they can view it.
    for (var detail in transaction.details) {
      if (detail.account != null) {
        if (isOwner(user, detail.account!)) {
          return true;
        }
      }
    }

    // 4. Group-Only Access: NOT allowed to see others' transactions
    // (Group members can only see their own transactions — handled by check #2 above)
    return false;
  }

  /// Check if user can View Account Balance
  bool canViewBalance(User user) {
    if (user.isAssociate) {
      return false; // HIDDEN for Associates
    }
    return true; // Visible for Admin, Management, Viewer
  }

  /// Check if user can Access System Settings
  bool canAccessSettings(User user) {
    return user.isAdmin;
  }

  /// Check if user can View All Reports
  bool canViewReports(User user) {
    if (user.isAssociate) return false;
    return true; // Admin, Management, Viewer
  }
}
