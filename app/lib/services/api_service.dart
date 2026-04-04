import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/serial_item.dart';

class ApiService {
  final String baseUrl;
  final http.Client client;

  ApiService({required this.baseUrl, http.Client? client})
      : client = client ?? http.Client();

  Future<Map<String, dynamic>> scanImage(String base64Image) async {
    final response = await client.post(
      Uri.parse('$baseUrl/scan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': base64Image}),
    );
    if (response.statusCode != 200) {
      throw Exception('Erro ao processar imagem: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<int>> exportFile(String format, List<SerialItem> serials) async {
    final response = await client.post(
      Uri.parse('$baseUrl/export'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'format': format,
        'serials': serials.map((s) => s.toMap()).toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Erro ao gerar arquivo: ${response.body}');
    }
    return response.bodyBytes.toList();
  }

  Future<void> sendEmail(
    String to,
    String mode,
    String? format,
    List<SerialItem> serials,
  ) async {
    final response = await client.post(
      Uri.parse('$baseUrl/email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'to': to,
        'mode': mode,
        'format': format,
        'serials': serials.map((s) => s.toMap()).toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Erro ao enviar e-mail: ${response.body}');
    }
  }
}
