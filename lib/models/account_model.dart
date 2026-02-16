import 'user_model.dart';

class Account {
  final String name;
  final List<String> owners; // Changed from single primaryOwner
  final List<String> groupIds;
  final String type; // e.g., Asset, Liability, Expense, Income
  final String? subCategory; // e.g., Cash & Bank, Fixed Assets
  final String? defaultCurrency;
  final bool active;
  final double totalDebit;
  final double totalCredit;

  Account({
    required this.name,
    required this.owners,
    required this.groupIds,
    required this.type,
    this.subCategory,
    this.defaultCurrency,
    this.active = true,
    this.totalDebit = 0.0,
    this.totalCredit = 0.0,
  });

  Account copyWith({
    String? name,
    List<String>? owners,
    List<String>? groupIds,
    String? type,
    String? subCategory,
    String? defaultCurrency,
    bool? active,
    double? totalDebit,
    double? totalCredit,
  }) {
    return Account(
      name: name ?? this.name,
      owners: owners ?? this.owners,
      groupIds: groupIds ?? this.groupIds,
      type: type ?? this.type,
      subCategory: subCategory ?? this.subCategory,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      active: active ?? this.active,
      totalDebit: totalDebit ?? this.totalDebit,
      totalCredit: totalCredit ?? this.totalCredit,
    );
  }

  // Backward compatibility getter
  String get primaryOwner => owners.isNotEmpty ? owners.first : '';

  factory Account.fromJson(Map<String, dynamic> json) {
    // Handle legacy single owner or new list
    List<String> parsedOwners = [];

    if (json['owners'] != null) {
      parsedOwners = (json['owners'] as String)
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (json['primary_owner'] != null) {
      parsedOwners.add(json['primary_owner'].toString().trim());
    } else if (json['owner'] != null) {
      parsedOwners.add(json['owner'].toString().trim());
    }

    return Account(
      name: (json['name'] ?? '').toString().trim(),
      owners: parsedOwners,
      groupIds:
          (json['group_ids'] as String?)
              ?.split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      type: (json['type'] ?? 'General').toString().trim(),
      subCategory: json['sub_category']?.toString().trim(),
      defaultCurrency: json['default_currency']?.toString().trim(),
      active:
          json['active'] == true ||
          json['active'].toString().toUpperCase() == 'TRUE',
      totalDebit:
          double.tryParse(json['total_debit']?.toString() ?? '0') ?? 0.0,
      totalCredit:
          double.tryParse(json['total_credit']?.toString() ?? '0') ?? 0.0,
    );
  }

  bool canEdit(User user) {
    // Check if user is in owners list
    return owners.any(
      (ownerEmail) => ownerEmail.toLowerCase() == user.email.toLowerCase(),
    );
  }

  bool canView(User user) {
    if (canEdit(user)) return true;
    return false;
  }

  double get balance {
    bool isDebitNormal = ['Asset', 'Expense'].contains(type);
    if (isDebitNormal) {
      return totalDebit - totalCredit;
    } else {
      return totalCredit - totalDebit;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Account && other.name == name;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'owners': owners.join(','),
      'group_ids': groupIds.join(','),
      'type': type,
      'sub_category': subCategory,
      'default_currency': defaultCurrency,
      'active': active,
      'total_debit': totalDebit,
      'total_credit': totalCredit,
    };
  }

  @override
  int get hashCode => name.hashCode;
}
