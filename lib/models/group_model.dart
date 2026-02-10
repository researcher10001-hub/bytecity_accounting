class GroupModel {
  final String id;
  final String name;
  final String description;

  GroupModel({required this.id, required this.name, required this.description});

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}
