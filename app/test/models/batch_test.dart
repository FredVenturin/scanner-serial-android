import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_serial/models/batch.dart';
import 'package:scanner_serial/models/serial_item.dart';

void main() {
  group('Batch', () {
    test('toMap e fromMap preservam todos os campos', () {
      final item = SerialItem(
        serial: 'SN-001',
        note: 'Dell',
        capturedAt: DateTime.parse('2026-04-07T10:00:00.000'),
      );
      final batch = Batch(
        id: 'abc-123',
        name: 'Sala 3',
        createdAt: DateTime.parse('2026-04-07T09:00:00.000'),
        items: [item],
      );

      final map = batch.toMap();
      final restored = Batch.fromMap(map);

      expect(restored.id, 'abc-123');
      expect(restored.name, 'Sala 3');
      expect(restored.createdAt, DateTime.parse('2026-04-07T09:00:00.000'));
      expect(restored.items.length, 1);
      expect(restored.items[0].serial, 'SN-001');
      expect(restored.items[0].note, 'Dell');
    });

    test('fromMap com items vazio', () {
      final batch = Batch(
        id: 'xyz-456',
        name: 'Andar 2',
        createdAt: DateTime.parse('2026-04-07T09:00:00.000'),
        items: [],
      );
      final restored = Batch.fromMap(batch.toMap());
      expect(restored.items, isEmpty);
    });

    test('copyWith atualiza apenas os campos fornecidos', () {
      final batch = Batch(
        id: 'abc-123',
        name: 'Sala 3',
        createdAt: DateTime.parse('2026-04-07T09:00:00.000'),
        items: [],
      );
      final updated = batch.copyWith(name: 'Sala 4');
      expect(updated.id, 'abc-123');
      expect(updated.name, 'Sala 4');
      expect(updated.createdAt, batch.createdAt);
    });
  });
}
