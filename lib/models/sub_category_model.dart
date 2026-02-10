class SubCategory {
  final String type;
  final String name;

  SubCategory({required this.type, required this.name});

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(type: json['type'] ?? '', name: json['name'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'name': name};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubCategory &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          name == other.name;

  @override
  int get hashCode => type.hashCode ^ name.hashCode;
}
