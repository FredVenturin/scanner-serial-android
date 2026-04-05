class SerialItem {
  final String serial;
  final String? note;
  final DateTime capturedAt;

  SerialItem({required this.serial, this.note, DateTime? capturedAt})
      : capturedAt = capturedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {'serial': serial, 'note': note};

  Map<String, dynamic> toFullMap() => {
        'serial': serial,
        'note': note,
        'capturedAt': capturedAt.toIso8601String(),
      };

  factory SerialItem.fromMap(Map<String, dynamic> map) {
    return SerialItem(
      serial: map['serial'] as String,
      note: map['note'] as String?,
      capturedAt: map['capturedAt'] != null
          ? DateTime.parse(map['capturedAt'] as String)
          : null,
    );
  }
}
