class Box {
  final String id;
  String name;
  String? description;
  bool fragile;
  final DateTime createdAt;

  Box({
    required this.id,
    required this.name,
    this.description,
    this.fragile = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'fragile': fragile,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Box.fromMap(Map<String, dynamic> map) => Box(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        fragile: (map['fragile'] as bool?) ?? false,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  Map<String, dynamic> toExportMap() => {
        'id': id,
        'name': name,
        'description': description,
        'fragile': fragile,
        'createdAt': createdAt.toIso8601String(),
      };
}
