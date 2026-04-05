import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanner_serial/services/storage_service.dart';
import 'package:scanner_serial/models/serial_item.dart';

void main() {
  group('StorageService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveSession e loadSession preservam nome e itens', () async {
      final service = StorageService();
      final items = [
        SerialItem(serial: 'SN-001', note: 'Dell', capturedAt: DateTime.parse('2026-04-05T10:00:00.000')),
        SerialItem(serial: 'SN-002', capturedAt: DateTime.parse('2026-04-05T11:00:00.000')),
      ];

      await service.saveSession('Sala 3', items);
      final result = await service.loadSession();

      expect(result, isNotNull);
      expect(result!.name, 'Sala 3');
      expect(result.items.length, 2);
      expect(result.items[0].serial, 'SN-001');
      expect(result.items[0].note, 'Dell');
      expect(result.items[1].serial, 'SN-002');
      expect(result.items[1].note, isNull);
    });

    test('loadSession retorna null quando nao ha dados salvos', () async {
      final service = StorageService();
      final result = await service.loadSession();
      expect(result, isNull);
    });

    test('clearSession remove dados salvos', () async {
      final service = StorageService();
      await service.saveSession('Test', [SerialItem(serial: 'SN-X')]);
      await service.clearSession();
      final result = await service.loadSession();
      expect(result, isNull);
    });
  });
}
