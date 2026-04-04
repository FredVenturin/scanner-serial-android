import 'package:flutter/material.dart';
import '../models/serial_item.dart';
import '../services/api_service.dart';

class ConfirmScreen extends StatelessWidget {
  final String serial;
  final String confidence;
  final List<SerialItem> sessionList;
  final ApiService apiService;

  const ConfirmScreen({
    super.key,
    required this.serial,
    required this.confidence,
    required this.sessionList,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('ConfirmScreen — em breve')),
      );
}
