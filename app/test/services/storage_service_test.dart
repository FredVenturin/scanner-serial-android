import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanner_serial/services/storage_service.dart';
import 'package:scanner_serial/models/batch.dart';
import 'package:scanner_serial/models/serial_item.dart';

void main() {
  group('StorageService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveBatches e loadBatches preservam lista de lotes', () async {
      final service = StorageService();
      final batches = [
        Batch(
          id: 'b1',
          name: 'Sala 3',
          createdAt: DateTime.parse('2026-04-07T09:00:00.000'),
          items: [SerialItem(serial: 'SN-001', capturedAt: DateTime.parse('2026-04-07T10:00:00.000'))],
        ),
        Batch(
          id: 'b2',
          name: 'Andar 2',
          createdAt: DateTime.parse('2026-04-07T09:30:00.000'),
          items: [],
        ),
      ];

      await service.saveBatches(batches);
      final loaded = await service.loadBatches();

      expect(loaded.length, 2);
      expect(loaded[0].id, 'b1');
      expect(loaded[0].name, 'Sala 3');
      expect(loaded[0].items.length, 1);
      expect(loaded[0].items[0].serial, 'SN-001');
      expect(loaded[1].id, 'b2');
      expect(loaded[1].items, isEmpty);
    });

    test('loadBatches retorna lista vazia quando nao ha dados', () async {
      final service = StorageService();
      final result = await service.loadBatches();
      expect(result, isEmpty);
    });

    test('saveLastBatchId e loadLastBatchId preservam ID', () async {
      final service = StorageService();
      await service.saveLastBatchId('batch-xyz');
      final id = await service.loadLastBatchId();
      expect(id, 'batch-xyz');
    });

    test('loadLastBatchId retorna null quando nao ha ID salvo', () async {
      final service = StorageService();
      final id = await service.loadLastBatchId();
      expect(id, isNull);
    });

    test('clearAll remove todos os dados', () async {
      final service = StorageService();
      final batch = Batch(
        id: 'b1',
        name: 'Test',
        createdAt: DateTime.parse('2026-04-07T09:00:00.000'),
        items: [],
      );
      await service.saveBatches([batch]);
      await service.saveLastBatchId('b1');
      await service.clearAll();

      final batches = await service.loadBatches();
      final lastId = await service.loadLastBatchId();
      expect(batches, isEmpty);
      expect(lastId, isNull);
    });
  });
}
