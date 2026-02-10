class GroupModel {
  final String id;
  final String name;
  final String description;
  final String type; // 'permission', 'report', or 'both'
  final List<String> accountNames;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    this.type = 'permission',
    this.accountNames = const [],
  });

  bool get isPermission => type == 'permission' || type == 'both';
  bool get isReport => type == 'report' || type == 'both';

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'permission',
      accountNames:
          (json['accounts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
