import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../core/services/api_service.dart';
import '../core/services/session_manager.dart';
import '../core/constants/api_constants.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  Timer? _sessionTimer;

  final ApiService _apiService = ApiService();
  final SessionManager _sessionManager = SessionManager();

  AuthProvider() {
    ApiService.onUnauthorized = () {
      logout();
    };
  }

  // ... getters ...
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  @override
  void dispose() {
    _stopSessionMonitor();
    super.dispose();
  }

  Future<void> loadSession() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _sessionManager.getUser();
      if (_user != null) {
        if (!_user!.isActive) {
          _user = null;
          await _sessionManager.logout();
        } else {
          _startSessionMonitor(); // Start monitoring
        }
      }
    } catch (e) {
      // Failed to load session
    }
    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.postRequest(ApiConstants.actionLogin, {
        'email': email,
        'password': password,
      });

      _user = User.fromJson(data);

      if (!_user!.isActive) {
        _user = null;
        throw ApiException('Your account has been suspended.');
      }

      await _sessionManager.saveUser(_user!);
      _startSessionMonitor(); // Start monitoring

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _user = null;
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_user == null) throw ApiException('User not logged in');

      await _apiService.postRequest(ApiConstants.actionChangePassword, {
        'email': _user!.email,
        'current_password': currentPassword,
        'new_password': newPassword,
      });

      _isLoading = false;
      notifyListeners();
      return null; // Success (no error message)
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString(); // Return error message
    }
  }

  Future<void> updateUserLocally(User updatedUser) async {
    _user = updatedUser;
    await _sessionManager.saveUser(_user!);
    notifyListeners();
  }

  Future<void> logout() async {
    _stopSessionMonitor();
    // Remove this device's token from the server (fire-and-forget)
    if (_user != null && _user!.sessionToken != null) {
      try {
        await _apiService.postRequest(ApiConstants.actionLogoutUser, {
          'email': _user!.email,
          'session_token': _user!.sessionToken,
        });
      } catch (_) {
        // Ignore server errors — local logout always proceeds
      }
    }
    await _sessionManager.logout();
    _user = null;
    notifyListeners();
  }

  // --- SESSION MONITOR ---
  void _startSessionMonitor() {
    _stopSessionMonitor(); // Ensure no duplicate timers

    // Check immediately to sync latest permissions/status
    _checkSessionValidity();

    // Check every 5 minutes (Production Mode)
    _sessionTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkSessionValidity();
    });
  }

  void _stopSessionMonitor() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  Future<void> _checkSessionValidity() async {
    if (_user == null || _user!.sessionToken == null) return;

    try {
      // Intentionally NOT using _isLoading/notifyListeners to keep it silent
      final response = await _apiService.postRequest(
        ApiConstants.actionCheckSession,
        {'email': _user!.email, 'session_token': _user!.sessionToken},
      );

      if (response != null && response is Map<String, dynamic>) {
        if (response['valid'] == true) {
          // Sync User Data (Permissions, Role, Status)
          // We can just re-parse the user from the response as it now returns full profile
          final updatedUser = User.fromJson(response);

          // Check for changes that imply a need to update state
          if (updatedUser.allowForeignCurrency != _user!.allowForeignCurrency ||
              updatedUser.allowAutoApproval != _user!.allowAutoApproval ||
              updatedUser.role != _user!.role ||
              updatedUser.status != _user!.status ||
              updatedUser.pinnedAccountName != _user!.pinnedAccountName) {
            _user = updatedUser;
            await _sessionManager.saveUser(_user!);
            notifyListeners();
          }
        }
      }
      // If fail (401/Unauthorized), ApiService.onUnauthorized will trigger logout().
    } catch (e) {
      // If network error, ignore (don't logout for just bad internet once)
      // But if it's unauthorized (handled by ApiService), it will logout.
      // print('Heartbeat check failed: $e');
    }
  }
}
