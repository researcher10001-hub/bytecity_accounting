import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/account_group_model.dart';
import '../core/constants/api_constants.dart';

class AccountGroupService {
  final String _baseUrl = ApiConstants.baseUrl;

  Future<List<AccountGroup>> getAccountGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=${ApiConstants.actionGetGroups}'),
      );

      if (response.statusCode == 200) {
        // final List<dynamic> data = json.decode(response.body)['data'];
        // Wait, json.decode returns dynamic. access ['data'] returns dynamic.
        // So I should cast it safely.
        final dynamic jsonData = json.decode(response.body);
        if (jsonData['data'] is List) {
          final List<dynamic> listData = jsonData['data'];
          return listData.map((json) => AccountGroup.fromJson(json)).toList();
        }
        return [];
      } else {
        throw Exception('Failed to load account groups');
      }
    } catch (e) {
      print('Error fetching account groups: $e');
      return [];
    }
  }

  Future<bool> saveAccountGroup(AccountGroup group) async {
    try {
      // Determine action based on ID presence? No, provider calls specific actions?
      // Provider logic: addGroup -> saveAccountGroup. updateGroup -> saveAccountGroup.
      // But Code.gs distinguishes createGroup vs updateGroup.
      // This service method needs to know which one.
      // Current implementation: always calls saveAccountGroup?
      // But Code.gs has createGroup and updateGroup.
      // I should update this method to choose action based on ID.
      // Wait, ID is always present in model? Empty string for new?

      final action = group.id.isEmpty
          ? ApiConstants.actionCreateGroup
          : ApiConstants.actionUpdateGroup;

      final response = await http.post(
        Uri.parse('$_baseUrl?action=$action'),
        body: json.encode(group.toJson()),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['status'] == 'success';
      }
      return false;
    } catch (e) {
      print('Error saving account group: $e');
      return false;
    }
  }

  Future<bool> deleteAccountGroup(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=${ApiConstants.actionDeleteGroup}'),
        body: json.encode({'id': id}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['status'] == 'success';
      }
      return false;
    } catch (e) {
      print('Error deleting account group: $e');
      return false;
    }
  }
}
