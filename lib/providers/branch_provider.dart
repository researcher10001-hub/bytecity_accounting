import 'package:flutter/material.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_constants.dart';
import '../../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BranchProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<String> _branches = [
    'HQ',
    'JFP',
    'Uttara',
    'Dhanmondi'
  ]; // Fallback options
  bool _isLoading = false;
  String? _error;

  List<String> get branches => _branches;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Cache Key
  static const String _cacheKey = 'cached_branches';

  BranchProvider() {
    _loadFromCache();
  }

  Future<void> fetchBranches(User? user) async {
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final payload = {
        'user_email': user.email,
        'session_token': user.sessionToken,
      };

      final response = await _apiService.postRequest(
        ApiConstants.actionGetBranches,
        payload,
      );

      if (response is List) {
        _branches = response.map((e) => e.toString()).toList();
        if (_branches.isEmpty) {
          _branches = ['HQ']; // Absolute fallback
        }
        _saveToCache(_branches);
        _error = null;
      } else {
        _error = "Invalid branch data received";
      }
    } catch (e) {
      _error = e.toString();
      print("Error fetching branches: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString(_cacheKey);
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        _branches = decoded.map((e) => e.toString()).toList();
        notifyListeners();
      }
    } catch (e) {
      print("Error loading branches from cache: $e");
    }
  }

  Future<void> _saveToCache(List<String> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (e) {
      print("Error saving branches to cache: $e");
    }
  }
}
