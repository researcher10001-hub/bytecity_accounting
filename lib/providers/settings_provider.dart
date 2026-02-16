import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_constants.dart';

class SettingsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _showDashboardActivity = true;

  // ERPNext Settings
  String _erpUrl = '';
  String _erpApiKey = '';
  String _erpApiSecret = '';
  String _erpDocType = 'Journal Entry';
  bool _emailNotificationsEnabled = true;

  bool get isLoading => _isLoading;
  bool get showDashboardActivity => _showDashboardActivity;
  String get erpUrl => _erpUrl;
  String get erpApiKey => _erpApiKey;
  String get erpApiSecret => _erpApiSecret;
  String get erpDocType => _erpDocType;
  bool get emailNotificationsEnabled => _emailNotificationsEnabled;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _showDashboardActivity = prefs.getBool('show_dashboard_activity') ?? true;

    // Sync from server
    await fetchSettingsFromServer();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchSettingsFromServer() async {
    try {
      final response = await _apiService.postRequest(
        ApiConstants.actionGetSettings,
        {},
      );
      // ApiService already unwraps response['data'], so response IS the data
      if (response is Map<String, dynamic>) {
        _erpUrl = response['erp_url'] ?? '';
        _erpApiKey = response['erp_api_key'] ?? '';
        _erpApiSecret = response['erp_api_secret'] ?? '';
        _erpDocType = response['erp_doctype'] ?? 'Journal Entry';
        _emailNotificationsEnabled =
            response['email_notifications_enabled'] ?? true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to fetch settings from server: $e");
    }
  }

  Future<String?> updateSettingsOnServer({
    required String erpUrl,
    required String erpApiKey,
    required String erpApiSecret,
    required String erpDocType,
    required bool emailNotificationsEnabled,
  }) async {
    try {
      await _apiService.postRequest(ApiConstants.actionUpdateSettings, {
        'settings': {
          'erp_url': erpUrl,
          'erp_api_key': erpApiKey,
          'erp_api_secret': erpApiSecret,
          'erp_doctype': erpDocType,
          'email_notifications_enabled': emailNotificationsEnabled,
        },
      });

      // If postRequest succeeds, it means status was 'success' (it throws on error)
      _erpUrl = erpUrl;
      _erpApiKey = erpApiKey;
      _erpApiSecret = erpApiSecret;
      _erpDocType = erpDocType;
      _emailNotificationsEnabled = emailNotificationsEnabled;
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> toggleDashboardActivity(bool value) async {
    _showDashboardActivity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_dashboard_activity', value);
  }
}
