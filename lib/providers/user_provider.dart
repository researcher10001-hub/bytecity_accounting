import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_constants.dart';

class UserProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<User> _users = [];
  bool _isLoading = false;
  String? _error;

  List<User> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchUsers({bool forceRefresh = false}) async {
    if (!forceRefresh && _users.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.postRequest(
        ApiConstants.actionGetUsers,
        {},
      );

      if (response != null && response is List) {
        _users = (response).map((json) => User.fromJson(json)).toList();
      } else if (response != null && response['status'] == 'success') {
        final data = response['data'] as List;
        _users = data.map((json) => User.fromJson(json)).toList();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUser(User updatedUser) async {
    // Optimistic Update: Update local list immediately to keep UI responsive
    final index = _users.indexWhere((u) => u.email == updatedUser.email);
    User? previousUser;
    if (index != -1) {
      previousUser = _users[index];
      _users[index] = updatedUser;
      notifyListeners();
    }

    try {
      final payload = {
        'email': updatedUser.email,
        'name': updatedUser.name,
        'role': updatedUser.role,
        'designation': updatedUser.designation,
        'status': updatedUser.status,
        'group_ids': updatedUser.groupIds.join(','),
        'allow_foreign_currency': updatedUser.allowForeignCurrency,
        'allow_auto_approval': updatedUser.allowAutoApproval,
        'allow_date_edit': updatedUser.allowDateEdit,
      };

      await _apiService.postRequest(ApiConstants.actionUpdateUser, payload);
      return true;
    } catch (e) {
      _error = e.toString();
      // Rollback on failure
      if (index != -1 && previousUser != null) {
        _users[index] = previousUser;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> toggleDatePermission(String email, bool allowed) async {
    final index = _users.indexWhere((u) => u.email == email);
    if (index != -1) {
      final user = _users[index];
      return await updateUser(user.copyWith(allowDateEdit: allowed));
    }
    return false;
  }

  Future<bool> toggleCurrencyPermission(String email, bool allowed) async {
    final index = _users.indexWhere((u) => u.email == email);
    if (index != -1) {
      final user = _users[index];
      return await updateUser(user.copyWith(allowForeignCurrency: allowed));
    }
    return false;
  }

  Future<bool> toggleAutoApproval(String email, bool allowed) async {
    final index = _users.indexWhere((u) => u.email == email);
    if (index != -1) {
      final user = _users[index];
      return await updateUser(user.copyWith(allowAutoApproval: allowed));
    }
    return false;
  }

  Future<bool> addUser(
    String name,
    String email,
    String password,
    String role,
    String designation,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final payload = {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
        'designation': designation.trim(),
      };

      await _apiService.postRequest(ApiConstants.actionCreateUser, payload);

      // Optimistic Add
      final newUser = User(
        email: email.trim(),
        name: name.trim(),
        role: role,
        designation: designation.trim(),
        status: 'Active',
        allowAutoApproval: false, // Default false
      );
      _users.add(newUser);

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

  Future<bool> deleteUser(String email) async {
    // Only set loading if global blocking needed, else local
    // _isLoading = true;
    // notifyListeners();

    try {
      final payload = {'email': email};

      await _apiService.postRequest(ApiConstants.actionDeleteUser, payload);

      // Optimistic Soft Delete: Update status to 'Deleted' instead of removing
      final index = _users.indexWhere((u) => u.email == email);
      if (index != -1) {
        _users[index] = _users[index].copyWith(status: 'Deleted');
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      // _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserStatus(String email, String status) async {
    try {
      final payload = {'email': email, 'status': status};

      await _apiService.postRequest(ApiConstants.actionUpdateUser, payload);

      // Optimistic Update
      final index = _users.indexWhere((u) => u.email == email);
      if (index != -1) {
        final u = _users[index];
        _users[index] = u.copyWith(status: status);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> forceLogout(String email) async {
    try {
      final payload = {'email': email};
      await _apiService.postRequest(ApiConstants.actionForceLogout, payload);
      // No local state update needed as this affects session validity on server
      notifyListeners();
      return true;
    } catch (e) {
      print('Force Logout Failed: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String email, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final payload = {'email': email, 'newPassword': newPassword};

      await _apiService.postRequest(ApiConstants.actionChangePassword, payload);

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

  Future<bool> pinAccount(String email, String accountName) async {
    try {
      // Get current user to read existing pins
      final index = _users.indexWhere((u) => u.email == email);
      if (index == -1) return false;

      final currentPins = List<String>.from(_users[index].pinnedAccountNames);

      // Add new pin if not already pinned
      if (!currentPins.contains(accountName)) {
        currentPins.add(accountName);
      }

      final payload = {'email': email, 'pinned_account': currentPins.join(',')};

      await _apiService.postRequest(ApiConstants.actionUpdateUser, payload);

      // Optimistic Update
      _users[index] = _users[index].copyWith(pinnedAccountNames: currentPins);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> unpinAccount(String email, String accountName) async {
    try {
      // Get current user to read existing pins
      final index = _users.indexWhere((u) => u.email == email);
      if (index == -1) return false;

      final currentPins = List<String>.from(_users[index].pinnedAccountNames);

      // Remove the pin
      currentPins.remove(accountName);

      final payload = {'email': email, 'pinned_account': currentPins.join(',')};

      await _apiService.postRequest(ApiConstants.actionUpdateUser, payload);

      // Optimistic Update
      _users[index] = _users[index].copyWith(pinnedAccountNames: currentPins);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
