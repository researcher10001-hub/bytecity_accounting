import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_constants.dart';

class SettingsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _showDashboardActivity = true;

  bool get isLoading => _isLoading;
  bool get showDashboardActivity => _showDashboardActivity;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _showDashboardActivity = prefs.getBool('show_dashboard_activity') ?? true;
    _isLoading = false;
    notifyListeners();

    // Sync from server (Fire and forget, or handle errors)
    try {
      await _apiService.postRequest(ApiConstants.actionGetSettings, {});
    } catch (e) {
      debugPrint("Failed to fetch settings from server: $e");
    }
  }

  Future<void> toggleDashboardActivity(bool value) async {
    _showDashboardActivity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_dashboard_activity', value);
  }
}
