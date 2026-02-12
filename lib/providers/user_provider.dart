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
    // _isLoading = true; // Don't block the whole UI for an update
    // notifyListeners();

    try {
      final payload = {
        'email': updatedUser.email,
        'name': updatedUser.name,
        'role': updatedUser.role,
        'designation': updatedUser.designation,
        'status': updatedUser.status,
        'group_ids': updatedUser.groupIds.join(','),
        'allow_foreign_currency': updatedUser.allowForeignCurrency,
      };

      await _apiService.postRequest(ApiConstants.actionUpdateUser, payload);

      // Optimistic Update
      final index = _users.indexWhere((u) => u.email == updatedUser.email);
      if (index != -1) {
        _users[index] = updatedUser;
      }

      // _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      // _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> grantDatePermission(String email, {int hours = 24}) async {
    final index = _users.indexWhere((u) => u.email == email);
    if (index != -1) {
      final user = _users[index];
      final newUser = User(
        email: user.email,
        name: user.name,
        role: user.role,
        designation: user.designation,
        status: user.status,
        allowForeignCurrency: user.allowForeignCurrency,
        dateEditPermissionExpiresAt: DateTime.now().add(Duration(hours: hours)),
        groupIds: user.groupIds,
      );
      // Ideally call backend here, but assuming separate flow or handled by updateUser if generic
      // For now just optimistic local state, as updateUser endpoint doesn't support date permission yet in my implementation
      _users[index] = newUser;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> toggleCurrencyPermission(String email, bool allowed) async {
    final index = _users.indexWhere((u) => u.email == email);
    if (index != -1) {
      final user = _users[index];
      final newUser = User(
        email: user.email,
        name: user.name,
        role: user.role,
        designation: user.designation,
        status: user.status,
        allowForeignCurrency: allowed,
        dateEditPermissionExpiresAt: user.dateEditPermissionExpiresAt,
        groupIds: user.groupIds,
      );

      return await updateUser(newUser);
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

      // Optimistic Remove
      _users.removeWhere((u) => u.email == email);

      // _isLoading = false;
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
        _users[index] = User(
          name: u.name,
          email: u.email,
          role: u.role,
          status: status, // Update status
          allowForeignCurrency: u.allowForeignCurrency,
          dateEditPermissionExpiresAt: u.dateEditPermissionExpiresAt,
          groupIds: u.groupIds,
        );
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
}
