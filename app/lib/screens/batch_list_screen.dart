import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/batch.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import 'batch_detail_screen.dart';

class BatchListScreen extends StatefulWidget {
  final List<Batch> batches;
  final ApiService apiService;
  final void Function(List<Batch> batches) onBatchesUpdated;

  const BatchListScreen({
    super.key,
    required this.batches,
    required this.apiService,
    required this.onBatchesUpdated,
  });

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  late List<Batch> _batches;
  final StorageService _storage = StorageService();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _batches = List.from(widget.batches);
  }

  void _persist() {
    widget.onBatchesUpdated(_batches);
    _storage.saveBatches(_batches);
  }

  Future<void> _createBatch() async {
    if (_batches.length >= 5) return;
    final nameCtrl = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo lote'),
        content: TextField(
          controller: nameCtrl,
          maxLength: 30,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome do lote',
            hintText: 'Ex: Sala 3',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isNotEmpty) Navigator.pop(ctx, n);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (name == null || !mounted) return;

    setState(() {
      _batches.add(Batch(
        id: _uuid.v4(),
        name: name,
        createdAt: DateTime.now(),
        items: [],
      ));
    });
    _persist();
  }

  Future<void> _editBatch(int index) async {
    final nameCtrl = TextEditingController(text: _batches[index].name);

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar lote'),
        content: TextField(
          controller: nameCtrl,
          maxLength: 30,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome do lote'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isNotEmpty) Navigator.pop(ctx, n);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (name == null || !mounted) return;

    setState(() {
      _batches[index] = _batches[index].copyWith(name: name);
    });
    _persist();
  }

  Future<void> _deleteBatch(int index) async {
    final batchName = _batches[index].name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar lote'),
        content: Text(
            "Tem certeza? O lote '$batchName' e todas as suas séries serão apagados."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _batches.removeAt(index));
    _persist();
  }

  void _openBatch(int index) async {
    await Navigator.push<Batch>(
      context,
      MaterialPageRoute(
        builder: (_) => BatchDetailScreen(
          batch: _batches[index],
          allBatches: _batches,
          apiService: widget.apiService,
          onBatchUpdated: (b) {
            setState(() => _batches[index] = b);
            _persist();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final atLimit = _batches.length >= 5;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Meus Lotes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Tooltip(
            message: atLimit ? 'Limite de 5 lotes atingido' : 'Novo lote',
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: atLimit ? null : _createBatch,
            ),
          ),
        ],
      ),
      body: _batches.isEmpty
          ? const Center(
              child: Text(
                'Nenhum lote criado.\nToque em + para começar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _batches.length,
              itemBuilder: (_, i) {
                final batch = _batches[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onTap: () => _openBatch(i),
                    title: Text(
                      batch.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      '${batch.items.length} série${batch.items.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Color(0xFF4F46E5)),
                          onPressed: () => _editBatch(i),
                          tooltip: 'Editar nome',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _deleteBatch(i),
                          tooltip: 'Apagar lote',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
