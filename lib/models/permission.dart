class Permission {
  final String id;
  final String name;
  final String description;
  final String module;

  Permission({
    required this.id,
    required this.name,
    required this.description,
    required this.module,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'module': module,
      };

  factory Permission.fromJson(Map<String, dynamic> json) => Permission(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        module: json['module'],
      );
}
