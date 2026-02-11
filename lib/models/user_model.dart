import '../core/constants/role_constants.dart';

class User {
  final String name;
  final String email;
  final String designation;
  final String role; // Admin, Accountant, Viewer
  final String status; // Active, Suspended, Deleted
  final bool allowForeignCurrency;
  final String? dateEditPermissionExpiresAtString; // Helper if needed
  final DateTime? dateEditPermissionExpiresAt;
  final List<String> groupIds;
  final String? sessionToken;

  User({
    required this.name,
    required this.email,
    required this.role,
    this.designation = '',
    this.status = 'Active',
    this.allowForeignCurrency = false,
    this.dateEditPermissionExpiresAt,
    this.dateEditPermissionExpiresAtString,
    this.groupIds = const [],
    this.sessionToken,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    List<String> parsedGroups = [];
    if (json['group_ids'] != null && json['group_ids'].toString().isNotEmpty) {
      parsedGroups = json['group_ids']
          .toString()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Defensive trimming for all string fields
    String name = (json['name'] ?? '').toString().trim();
    String email = (json['email'] ?? '').toString().trim();
    String roleRaw = (json['role'] ?? 'Viewer').toString().trim();
    String designationRaw = (json['designation'] ?? '').toString().trim();
    String statusRaw = (json['status'] ?? '').toString().trim();

    // Use 'active' flag if status is missing or empty
    if (statusRaw.isEmpty) {
      if (json['active'] != null) {
        statusRaw =
            (json['active'] == true ||
                json['active'].toString().toUpperCase() == 'TRUE')
            ? 'Active'
            : 'Suspended';
      } else {
        statusRaw = 'Active';
      }
    } else {
      // Normalize common status strings to "Active" if close enough
      if (statusRaw.toLowerCase().startsWith('activ')) {
        statusRaw = 'Active';
      }
    }

    return User(
      name: name,
      email: email,
      role: roleRaw,
      designation: designationRaw,
      status: statusRaw,
      allowForeignCurrency: json['allow_foreign_currency'] == true,
      dateEditPermissionExpiresAt: json['date_edit_expires_at'] != null
          ? DateTime.tryParse(json['date_edit_expires_at'].toString().trim())
          : null,
      groupIds: parsedGroups,
      sessionToken: json['session_token']?.toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'designation': designation,
      'status': status,
      'allow_foreign_currency': allowForeignCurrency,
      'date_edit_expires_at': dateEditPermissionExpiresAt?.toIso8601String(),
      'group_ids': groupIds.join(','),
      'session_token': sessionToken,
    };
  }

  // Helper properties for roles
  bool get isAdmin => role.toLowerCase() == AppRoles.admin.toLowerCase();
  bool get isManagement =>
      role.toLowerCase() == AppRoles.management.toLowerCase();
  bool get isAssociate =>
      role.toLowerCase() == AppRoles.associate.toLowerCase() ||
      role.toLowerCase() == 'business operations associate'; // Backward compat
  bool get isViewer => role.toLowerCase() == AppRoles.viewer.toLowerCase();

  // Status Helpers
  bool get isActive => status == 'Active';
  bool get isSuspended => status == 'Suspended';
  bool get isDeleted => status == 'Deleted';

  bool get canEditDate {
    if (isAdmin) return true; // Admins can always edit
    if (dateEditPermissionExpiresAt == null) return false;
    return dateEditPermissionExpiresAt!.isAfter(DateTime.now());
  }
}
