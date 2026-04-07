import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/batch.dart';
import '../services/api_service.dart';

class BatchDetailScreen extends StatefulWidget {
  final Batch batch;
  final List<Batch> allBatches;
  final ApiService apiService;
  final void Function(Batch batch) onBatchUpdated;

  const BatchDetailScreen({
    super.key,
    required this.batch,
    required this.allBatches,
    required this.apiService,
    required this.onBatchUpdated,
  });

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  late Batch _batch;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _batch = widget.batch;
  }

  void _removeItem(int index) {
    final updated = _batch.copyWith(
      items: List.from(_batch.items)..removeAt(index),
    );
    setState(() => _batch = updated);
    widget.onBatchUpdated(_batch);
  }

  void _copyAll() {
    final text = _batch.items.map((e) => e.serial).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seriais copiados para a área de transferência!')),
    );
  }

  Future<void> _downloadFile(String format) async {
    setState(() => _isLoading = true);
    try {
      final bytes = await widget.apiService.exportFile(format, _batch.items);
      final dir = await getTemporaryDirectory();
      final safeName =
          _batch.name.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
      final fileName = safeName.isEmpty ? 'seriais' : safeName;
      final file = File('${dir.path}/$fileName.$format');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arquivo salvo em: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDownloadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Escolha o formato',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...['pdf', 'xlsx', 'txt', 'docx'].map(
              (format) => ListTile(
                leading: const Icon(Icons.download),
                title: Text(format.toUpperCase()),
                onTap: () {
                  Navigator.pop(context);
                  _downloadFile(format);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _batch.name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(
                '${_batch.items.length} série${_batch.items.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: Colors.white24,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : Column(
              children: [
                Expanded(
                  child: _batch.items.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum serial neste lote.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _batch.items.length,
                          itemBuilder: (_, i) {
                            final item = _batch.items[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                title: Text(
                                  item.serial,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  item.note ?? 'sem observação',
                                  style: TextStyle(
                                    color: item.note != null
                                        ? Colors.grey[700]
                                        : Colors.grey[400],
                                    fontStyle: item.note == null
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () => _removeItem(i),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        top: BorderSide(color: Color(0xFFE0E0E0))),
                  ),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            _batch.items.isEmpty ? null : _showDownloadOptions,
                        icon: const Icon(Icons.download),
                        label: const Text(
                            'Baixar arquivo (PDF / XLSX / TXT / DOC)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _batch.items.isEmpty ? null : _copyAll,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar todos'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
