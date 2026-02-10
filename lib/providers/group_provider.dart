import 'package:flutter/material.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_constants.dart';
import '../models/group_model.dart';

class GroupProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<GroupModel> _groups = [];
  bool _isLoading = false;
  String? _error;

  List<GroupModel> get groups => _groups;
  List<GroupModel> get permissionGroups =>
      _groups.where((g) => g.isPermission).toList();
  List<GroupModel> get reportGroups =>
      _groups.where((g) => g.isReport).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchGroups({bool forceRefresh = false}) async {
    if (_groups.isNotEmpty && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.postRequest(
        ApiConstants.actionGetGroups,
        {},
      );

      // ApiService already unwraps {status, data} and returns only 'data'
      // So response is directly the List<dynamic>
      if (response is List) {
        _groups = (response).map((json) => GroupModel.fromJson(json)).toList();
        _error = null;
      } else {
        _error = 'Invalid response format';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper to find group names
  String getGroupNames(List<String> groupIds) {
    return _groups
        .where((g) => groupIds.contains(g.id))
        .map((g) => g.name)
        .join(', ');
  }

  Future<bool> addGroup(
    String name,
    String description, {
    String type = 'permission',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.postRequest(
        ApiConstants.actionCreateGroup,
        {'name': name, 'description': description, 'type': type},
      );

      // ApiService returns the unwrapped 'data' which is {message, id}
      if (response is Map && response.containsKey('id')) {
        final id = response['id'];
        _groups.add(
          GroupModel(id: id, name: name, description: description, type: type),
        );
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to create group';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateGroup(
    String id,
    String name,
    String description, {
    String type = 'permission',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.postRequest(
        ApiConstants.actionUpdateGroup,
        {'id': id, 'name': name, 'description': description, 'type': type},
      );

      // ApiService returns unwrapped data {message: 'Group updated'}
      if (response is Map && response.containsKey('message')) {
        final index = _groups.indexWhere((g) => g.id == id);
        if (index != -1) {
          _groups[index] = GroupModel(
            id: id,
            name: name,
            description: description,
            type: type,
          );
          notifyListeners();
        }
        return true;
      } else {
        _error = 'Failed to update group';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteGroup(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.postRequest(
        ApiConstants.actionDeleteGroup,
        {'id': id},
      );

      // ApiService returns unwrapped data {message: 'Group deleted'}
      if (response is Map && response.containsKey('message')) {
        _groups.removeWhere((g) => g.id == id);
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to delete group';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
