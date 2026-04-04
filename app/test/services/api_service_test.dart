import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:scanner_serial/models/serial_item.dart';
import 'package:scanner_serial/services/api_service.dart';

@GenerateMocks([http.Client])
import 'api_service_test.mocks.dart';

void main() {
  group('ApiService.scanImage', () {
    test('retorna serial e confidence quando backend responde 200', () async {
      final mockClient = MockClient();
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
            jsonEncode({'serial': 'SN-123', 'confidence': 'high'}),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final service = ApiService(
        baseUrl: 'http://localhost:3000',
        client: mockClient,
      );
      final result = await service.scanImage('base64string');

      expect(result['serial'], 'SN-123');
      expect(result['confidence'], 'high');
    });

    test('lança Exception quando backend responde erro', () async {
      final mockClient = MockClient();
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('{"error":"falha"}', 500));

      final service = ApiService(
        baseUrl: 'http://localhost:3000',
        client: mockClient,
      );

      expect(() => service.scanImage('base64'), throwsException);
    });
  });

  group('ApiService.sendEmail', () {
    test('completa sem erro quando backend responde 200', () async {
      final mockClient = MockClient();
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
            jsonEncode({'success': true, 'message': 'E-mail enviado'}),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final service = ApiService(
        baseUrl: 'http://localhost:3000',
        client: mockClient,
      );
      final serials = [SerialItem(serial: 'SN-123', note: 'Teste')];

      await expectLater(
        service.sendEmail('a@b.com', 'text', null, serials),
        completes,
      );
    });
  });

  group('ApiService.exportFile', () {
    test('retorna bytes quando backend responde 200', () async {
      final mockClient = MockClient();
      final fakeBytes = [80, 68, 70]; // "PDF" em bytes
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response.bytes(
            fakeBytes,
            200,
            headers: {'content-type': 'application/pdf'},
          ));

      final service = ApiService(
        baseUrl: 'http://localhost:3000',
        client: mockClient,
      );
      final serials = [SerialItem(serial: 'SN-123')];
      final result = await service.exportFile('pdf', serials);

      expect(result, fakeBytes);
    });
  });
}
