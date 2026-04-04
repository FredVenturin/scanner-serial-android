import 'package:flutter/material.dart';
import '../models/serial_item.dart';
import '../services/api_service.dart';

class ListScreen extends StatelessWidget {
  final List<SerialItem> sessionList;
  final ApiService apiService;
  final void Function(List<SerialItem>) onListUpdated;

  const ListScreen({
    super.key,
    required this.sessionList,
    required this.apiService,
    required this.onListUpdated,
  });

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('ListScreen — em breve')),
      );
}
