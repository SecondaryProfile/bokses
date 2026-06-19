enum ItemLabel { fragile, battery, liquid }

class Item {
  final String id;
  String name;
  String? photoPath;
  final String boxId;
  final DateTime createdAt;
  List<ItemLabel> labels;

  Item({
    required this.id,
    required this.name,
    this.photoPath,
    required this.boxId,
    required this.createdAt,
    List<ItemLabel>? labels,
  }) : labels = labels ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'photoPath': photoPath,
        'boxId': boxId,
        'createdAt': createdAt.toIso8601String(),
        'labels': labels.map((l) => l.name).toList(),
      };

  factory Item.fromMap(Map<String, dynamic> map) => Item(
        id: map['id'] as String,
        name: map['name'] as String,
        photoPath: map['photoPath'] as String?,
        boxId: map['boxId'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        labels: ((map['labels'] as List<dynamic>?) ?? [])
            .map((k) {
              try {
                return ItemLabel.values.firstWhere((l) => l.name == k);
              } catch (_) {
                return null;
              }
            })
            .whereType<ItemLabel>()
            .toList(),
      );

  Map<String, dynamic> toExportMap() => {
        'id': id,
        'name': name,
        'boxId': boxId,
        'createdAt': createdAt.toIso8601String(),
        'labels': labels.map((l) => l.name).toList(),
      };
}
