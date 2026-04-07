import 'serial_item.dart';

class Batch {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<SerialItem> items;

  Batch({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.items,
  });

  Batch copyWith({String? name, List<SerialItem>? items}) {
    return Batch(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'items': items.map((i) => i.toFullMap()).toList(),
      };

  factory Batch.fromMap(Map<String, dynamic> map) {
    return Batch(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      items: (map['items'] as List<dynamic>)
          .map((i) => SerialItem.fromMap(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
