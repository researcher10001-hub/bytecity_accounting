import '../core/constants/role_constants.dart';

class User {
  final String name;
  final String email;
  final String designation;
  final String role; // Admin, Accountant, Viewer
  final String status; // Active, Suspended, Deleted
  final bool allowForeignCurrency;
  final bool allowDateEdit;
  final List<String> groupIds;
  final String? sessionToken;
  final bool allowAutoApproval; // New field for Management approval permission
  final List<String> pinnedAccountNames;

  User({
    required this.name,
    required this.email,
    required this.role,
    this.designation = '',
    this.status = 'Active',
    this.allowForeignCurrency = false,
    this.allowDateEdit = false,
    this.groupIds = const [],
    this.sessionToken,
    this.allowAutoApproval = false,
    this.pinnedAccountNames = const [],
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
        statusRaw = (json['active'] == true ||
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
      } else if (statusRaw.toLowerCase() == 'deleted') {
        statusRaw = 'Deleted';
      }
    }

    return User(
      name: name,
      email: email,
      role: roleRaw,
      designation: designationRaw,
      status: statusRaw,
      allowForeignCurrency: json['allow_foreign_currency'] == true,
      allowDateEdit: (json['allow_date_edit'] == true ||
          json['allow_date_edit'].toString().toUpperCase() == 'TRUE'),
      groupIds: parsedGroups,
      sessionToken: json['session_token']?.toString().trim(),
      allowAutoApproval: json['allow_auto_approval'] == true,
      pinnedAccountNames: _parsePinnedAccounts(json['pinned_account']),
    );
  }

  static List<String> _parsePinnedAccounts(dynamic value) {
    if (value == null) return [];
    final str = value.toString().trim();
    if (str.isEmpty) return [];
    return str
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'designation': designation,
      'status': status,
      'allow_foreign_currency': allowForeignCurrency,
      'allow_date_edit': allowDateEdit,
      'group_ids': groupIds.join(','),
      'session_token': sessionToken,
      'allow_auto_approval': allowAutoApproval,
      'pinned_account': pinnedAccountNames.join(','),
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
    return allowDateEdit;
  }

  User copyWith({
    String? name,
    String? email,
    String? designation,
    String? role,
    String? status,
    bool? allowForeignCurrency,
    bool? allowDateEdit,
    List<String>? groupIds,
    String? sessionToken,
    bool? allowAutoApproval,
    List<String>? pinnedAccountNames,
  }) {
    return User(
      name: name ?? this.name,
      email: email ?? this.email,
      designation: designation ?? this.designation,
      role: role ?? this.role,
      status: status ?? this.status,
      allowForeignCurrency: allowForeignCurrency ?? this.allowForeignCurrency,
      allowDateEdit: allowDateEdit ?? this.allowDateEdit,
      groupIds: groupIds ?? this.groupIds,
      sessionToken: sessionToken ?? this.sessionToken,
      allowAutoApproval: allowAutoApproval ?? this.allowAutoApproval,
      pinnedAccountNames: pinnedAccountNames ?? this.pinnedAccountNames,
    );
  }
}
