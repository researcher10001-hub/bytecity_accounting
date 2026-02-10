import 'package:flutter/material.dart';
import '../models/sub_category_model.dart';
import '../models/user_model.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_constants.dart';

class SubCategoryProvider with ChangeNotifier {
  List<SubCategory> _subCategories = [];
  bool _isLoading = false;
  String? _error; // For initialization/loading
  String? _actionError; // For add/update/delete side effects

  final ApiService _apiService = ApiService();

  List<SubCategory> get subCategories => _subCategories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get actionError => _actionError;

  Map<String, List<String>> get subCategoriesByType {
    final Map<String, List<String>> map = {
      'Asset': [],
      'Liability': [],
      'Income': [],
      'Expense': [],
      'Equity': [],
    };

    for (var sub in _subCategories) {
      if (map.containsKey(sub.type)) {
        map[sub.type]!.add(sub.name);
      }
    }

    return map;
  }

  Future<void> fetchSubCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.postRequest(
        ApiConstants.actionGetSubCategories,
        {},
      );

      if (data is List) {
        _subCategories = data
            .map((json) => SubCategory.fromJson(json))
            .toList();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addSubCategory(User user, String type, String name) async {
    if (!user.isAdmin) return false;

    _isLoading = true;
    _actionError = null;
    notifyListeners();

    try {
      final response = await _apiService.postRequest(
        ApiConstants.actionCreateSubCategory,
        {'type': type, 'name': name.trim()},
      );

      if (response is Map && response['success'] == false) {
        throw response['message'] ?? 'Failed to add';
      }

      // Optimistic update
      _subCategories.add(SubCategory(type: type, name: name.trim()));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _actionError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSubCategory(
    User user,
    String type,
    String oldName,
    String newName,
  ) async {
    if (!user.isAdmin) return false;

    _isLoading = true;
    _actionError = null;
    notifyListeners();

    try {
      final response = await _apiService.postRequest(
        ApiConstants.actionUpdateSubCategory,
        {'type': type, 'oldName': oldName, 'newName': newName.trim()},
      );

      if (response is Map && response['success'] == false) {
        throw response['message'] ?? 'Failed to update';
      }

      final index = _subCategories.indexWhere(
        (s) => s.type == type && s.name == oldName,
      );
      if (index != -1) {
        _subCategories[index] = SubCategory(type: type, name: newName.trim());
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _actionError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSubCategory(User user, String type, String name) async {
    if (!user.isAdmin) return false;

    _isLoading = true;
    _actionError = null;
    notifyListeners();

    try {
      final response = await _apiService.postRequest(
        ApiConstants.actionDeleteSubCategory,
        {'type': type, 'name': name},
      );

      if (response is Map && response['success'] == false) {
        throw response['message'] ?? 'Failed to delete';
      }

      _subCategories.removeWhere((s) => s.type == type && s.name == name);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _actionError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
