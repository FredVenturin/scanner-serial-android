import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_serial/models/serial_item.dart';

void main() {
  group('SerialItem', () {
    test('cria item com serial obrigatório e note nulo por padrão', () {
      final item = SerialItem(serial: 'SN-123');
      expect(item.serial, 'SN-123');
      expect(item.note, isNull);
      expect(item.capturedAt, isNotNull);
    });

    test('cria item com note preenchido', () {
      final item = SerialItem(serial: 'SN-456', note: 'Notebook Dell');
      expect(item.note, 'Notebook Dell');
    });

    test('toMap retorna serial e note corretamente', () {
      final item = SerialItem(serial: 'SN-789', note: 'Monitor');
      final map = item.toMap();
      expect(map['serial'], 'SN-789');
      expect(map['note'], 'Monitor');
    });

    test('toMap com note nulo retorna null no campo note', () {
      final item = SerialItem(serial: 'SN-000');
      expect(item.toMap()['note'], isNull);
    });
  });
}
