class AccountGroup {
  String id;
  String name;
  List<String> accountNames;

  AccountGroup({
    required this.id,
    required this.name,
    required this.accountNames,
  });

  factory AccountGroup.fromJson(Map<String, dynamic> json) {
    return AccountGroup(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      accountNames:
          (json['accounts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'accounts': accountNames};
  }
}
