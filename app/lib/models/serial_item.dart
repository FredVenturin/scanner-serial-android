class SerialItem {
  final String serial;
  final String? note;
  final DateTime capturedAt;

  SerialItem({required this.serial, this.note, DateTime? capturedAt})
      : capturedAt = capturedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {'serial': serial, 'note': note};
}
