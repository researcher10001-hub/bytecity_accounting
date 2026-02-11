import 'package:flutter/material.dart';
import '../models/account_model.dart';
import '../models/user_model.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_constants.dart';
import '../models/transaction_model.dart';
import '../services/permission_service.dart';

class AccountProvider with ChangeNotifier {
  List<Account> _accounts = [];
  bool _isLoading = false;
  String? _error;

  final ApiService _apiService = ApiService();

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAccounts(User? user, {bool forceRefresh = false}) async {
    if (user == null) return;

    if (!forceRefresh && _accounts.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.postRequest(
        ApiConstants.actionGetAccounts,
        {
          'email': user.email,
          '_': DateTime.now().millisecondsSinceEpoch.toString(), // Cache Buster
        },
      );

      if (data is List) {
        _accounts = (data)
            .map((json) => Account.fromJson(json))
            .toSet()
            .toList();

        // Filter based on permissions using PermissionService
        // This checks ownership AND group membership for BOA users
        if (!user.isAdmin && !user.isManagement && !user.isViewer) {
          _accounts = _accounts
              .where(
                (account) => PermissionService().canViewAccount(user, account),
              )
              .toList();
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Silent sync to update balances without loading state
  Future<void> syncBalances(User? user) async {
    if (user == null || _accounts.isEmpty) return;
    try {
      final data = await _apiService.postRequest(
        ApiConstants.actionGetAccounts,
        {'email': user.email},
      );
      if (data is List) {
        final newAccounts = (data)
            .map((json) => Account.fromJson(json))
            .toList();
        for (var i = 0; i < _accounts.length; i++) {
          final match = newAccounts.firstWhere(
            (a) => a.name == _accounts[i].name,
            orElse: () => _accounts[i],
          );
          _accounts[i] = match;
        }
        notifyListeners();
      }
    } catch (e) {
      // Just fail silently for background sync
    }
  }

  /// Alias for syncBalances used in HomeScreen timer
  Future<void> getBalances(User? user) => syncBalances(user);

  Future<bool> addAccount(
    User user,
    String name,
    String type,
    List<String> groupIds,
    List<String> owners,
    String currency,
    String? subCategory,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final payload = {
        'name': name.trim(),
        'type': type,
        'sub_category': subCategory ?? '',
        'owners': owners.join(','), // Send comma separated
        'group_ids': groupIds.join(','),
        'default_currency': currency,
      };

      await _apiService.postRequest(ApiConstants.actionCreateAccount, payload);

      // Optimistic Update
      final newAccount = Account(
        name: name.trim(),
        type: type,
        subCategory: subCategory,
        owners: owners,
        groupIds: groupIds,
        defaultCurrency: currency,
      );
      _accounts.add(newAccount);
      _accounts = _accounts.toSet().toList(); // Ensure uniqueness

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAccount(
    User user,
    Account oldAccount,
    String newName,
    String newType,
    List<String> newGroupIds,
    List<String> newOwners,
    String newCurrency,
    String? newSubCategory,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final payload = {
        'old_name': oldAccount.name,
        'new_name': newName.trim(),
        'type': newType,
        'sub_category': newSubCategory ?? '',
        'group_ids': newGroupIds.join(','),
        'user_email': user.email,
        'default_currency': newCurrency,
        'owners': newOwners.join(','),
      };

      await _apiService.postRequest(ApiConstants.actionUpdateAccount, payload);

      // Optimistic Update
      _accounts.remove(oldAccount);

      final updatedAccount = Account(
        name: newName.trim(),
        type: newType,
        subCategory: newSubCategory,
        owners: newOwners,
        groupIds: newGroupIds,
        defaultCurrency: newCurrency,
        totalDebit: oldAccount.totalDebit,
        totalCredit: oldAccount.totalCredit,
      );

      _accounts.add(updatedAccount);
      _accounts = _accounts.toSet().toList();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> deleteAccount(
    User user,
    String accountName,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.postRequest(
        ApiConstants.actionDeleteAccount,
        {'email': user.email, 'name': accountName},
      );

      // Response expected: {'message': ..., 'action': 'archived' | 'deleted'}

      // Refresh list to sync state (Archived accounts might become 'inactive')
      await fetchAccounts(user, forceRefresh: true);

      _isLoading = false;
      notifyListeners();

      if (response is Map<String, dynamic>) {
        return response;
      }
      return {'success': true, 'action': 'unknown'};
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update account balances based on transaction history
  void updateBalancesFromTransactions(List<TransactionModel> transactions) {
    if (_accounts.isEmpty) return;

    // 1. Reset balances map
    final Map<String, double> debitMap = {};
    final Map<String, double> creditMap = {};

    // Initialize map for existing accounts
    for (var acc in _accounts) {
      final key = acc.name.trim().toLowerCase();
      debitMap[key] = 0.0;
      creditMap[key] = 0.0;
    }

    // 2. Iterate transactions
    for (var tx in transactions) {
      // Skip Rejected
      if (tx.status == TransactionStatus.rejected) continue;

      for (var detail in tx.details) {
        if (detail.account == null) continue;

        final accName = detail.account!.name.trim().toLowerCase();

        // Accumulate (only if account exists in our owned list)
        if (debitMap.containsKey(accName)) {
          debitMap[accName] = (debitMap[accName] ?? 0.0) + detail.debit;
          creditMap[accName] = (creditMap[accName] ?? 0.0) + detail.credit;
        }
      }
    }

    // 3. Update Accounts
    bool hasChanges = false;
    final List<Account> updatedAccounts = [];

    for (var acc in _accounts) {
      final key = acc.name.trim().toLowerCase();
      final newDebit = debitMap[key] ?? 0.0;
      final newCredit = creditMap[key] ?? 0.0;

      if ((acc.totalDebit - newDebit).abs() > 0.01 ||
          (acc.totalCredit - newCredit).abs() > 0.01) {
        updatedAccounts.add(
          acc.copyWith(totalDebit: newDebit, totalCredit: newCredit),
        );
        hasChanges = true;
      } else {
        updatedAccounts.add(acc);
      }
    }

    if (hasChanges) {
      _accounts = updatedAccounts;
      notifyListeners();
    }
  }
}
