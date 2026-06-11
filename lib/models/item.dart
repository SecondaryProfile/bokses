class Item {
  final String id;
  String name;
  String? photoPath;
  final String boxId;
  final DateTime createdAt;

  Item({
    required this.id,
    required this.name,
    this.photoPath,
    required this.boxId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'photoPath': photoPath,
        'boxId': boxId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Item.fromMap(Map<String, dynamic> map) => Item(
        id: map['id'] as String,
        name: map['name'] as String,
        photoPath: map['photoPath'] as String?,
        boxId: map['boxId'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  Map<String, dynamic> toExportMap() => {
        'id': id,
        'name': name,
        'boxId': boxId,
        'createdAt': createdAt.toIso8601String(),
        // photoPath intentionally omitted — not portable
      };
}
