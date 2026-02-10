import 'package:flutter/material.dart';
import '../models/account_group_model.dart';
import '../services/account_group_service.dart';

class AccountGroupProvider with ChangeNotifier {
  final AccountGroupService _service = AccountGroupService();
  List<AccountGroup> _groups = [];
  bool _isLoading = false;

  List<AccountGroup> get groups => _groups;
  bool get isLoading => _isLoading;

  Future<void> fetchGroups() async {
    _isLoading = true;
    notifyListeners();
    try {
      _groups = await _service.getAccountGroups();
    } catch (e) {
      print('Error fetching groups in provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addGroup(AccountGroup group) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _service.saveAccountGroup(group);
      if (success) {
        await fetchGroups(); // Refresh list
        return true;
      }
      return false;
    } catch (e) {
      print('Error adding group: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateGroup(AccountGroup group) async {
    // Save uses the same logic for update if ID exists
    return addGroup(group);
  }

  Future<bool> deleteGroup(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _service.deleteAccountGroup(id);
      if (success) {
        _groups.removeWhere((g) => g.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting group: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
