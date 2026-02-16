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
      // Normalize type: trim whitespace and match case
      String type = sub.type.trim();

      // Handle potential case differences and plurals from Sheet
      final lowered = type.toLowerCase();
      if (lowered == 'asset' || lowered == 'assets') {
        type = 'Asset';
      } else if (lowered == 'liability' || lowered == 'liabilities') {
        type = 'Liability';
      } else if (lowered == 'income' || lowered == 'incomes') {
        type = 'Income';
      } else if (lowered == 'expense' || lowered == 'expenses') {
        type = 'Expense';
      } else if (lowered == 'equity' || lowered == 'equities') {
        type = 'Equity';
      }

      // Debug print to catch unmatched types
      // print('DEBUG: Processing SubCategory "${sub.name}" with Raw Type: "${sub.type}" -> Normalized: "$type"');

      if (map.containsKey(type)) {
        map[type]!.add(sub.name);
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
      } else if (data is Map && data['status'] == 'error') {
        throw data['message'] ?? 'Unknown error';
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
