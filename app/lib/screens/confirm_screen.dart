import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/batch.dart';
import '../models/serial_item.dart';
import '../services/storage_service.dart';

class ConfirmScreen extends StatefulWidget {
  final String serial;
  final String confidence;
  final List<Batch> batches;
  final String? lastBatchId;

  const ConfirmScreen({
    super.key,
    required this.serial,
    required this.confidence,
    required this.batches,
    this.lastBatchId,
  });

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late TextEditingController _serialController;
  late TextEditingController _noteController;
  late List<Batch> _batches;
  Batch? _selectedBatch;
  final StorageService _storage = StorageService();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _serialController = TextEditingController(
      text: widget.serial == 'SERIAL_NAO_ENCONTRADO' ? '' : widget.serial,
    );
    _noteController = TextEditingController();
    _batches = List.from(widget.batches);

    if (widget.lastBatchId != null) {
      try {
        _selectedBatch = _batches.firstWhere((b) => b.id == widget.lastBatchId);
      } catch (_) {
        _selectedBatch = null;
      }
    }
  }

  @override
  void dispose() {
    _serialController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _createBatchInline() async {
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

    final newBatch = Batch(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
      items: [],
    );
    setState(() {
      _batches.add(newBatch);
      _selectedBatch = newBatch;
    });
  }

  Future<void> _addToList() async {
    final serial = _serialController.text.trim();
    if (serial.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite o número de série antes de adicionar.'),
        ),
      );
      return;
    }

    if (_selectedBatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um lote de destino.')),
      );
      return;
    }

    // Check duplicate across ALL batches
    Batch? duplicateBatch;
    for (final batch in _batches) {
      final found = batch.items.any(
        (item) => item.serial.trim().toLowerCase() == serial.toLowerCase(),
      );
      if (found) {
        duplicateBatch = batch;
        break;
      }
    }

    if (duplicateBatch != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Série duplicada'),
          content: Text(
              'O serial "$serial" já existe no lote "${duplicateBatch!.name}". Deseja adicionar mesmo assim?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
              child: const Text('Sim, adicionar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
    }

    final note = _noteController.text.trim();
    final newItem = SerialItem(
      serial: serial,
      note: note.isEmpty ? null : note,
    );

    final updatedBatch = _selectedBatch!.copyWith(
      items: [..._selectedBatch!.items, newItem],
    );

    final updatedBatches = _batches.map((b) {
      return b.id == updatedBatch.id ? updatedBatch : b;
    }).toList();

    await _storage.saveLastBatchId(_selectedBatch!.id);
    if (!mounted) return;
    Navigator.pop(context, updatedBatches);
  }

  void _discard() => Navigator.pop(context, null);

  bool get _serialNotFound =>
      widget.serial == 'SERIAL_NAO_ENCONTRADO' || widget.confidence == 'low';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _discard,
        ),
        title: const Text(
          'Confirmar Serial',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_serialNotFound)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Serial não identificado automaticamente. Digite manualmente abaixo.',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0FF),
                border: Border.all(color: const Color(0xFFC7D2FE)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SÉRIE DETECTADA',
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _serialController,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Digite o número de série',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '✏️ Toque para corrigir',
                    style: TextStyle(color: Color(0xFF6366F1), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'OBSERVAÇÃO (OPCIONAL)',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Ex: Notebook Dell — Sala 3',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'LOTE DE DESTINO',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            if (_batches.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Você não tem lotes criados ainda.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _createBatchInline,
                    icon: const Icon(Icons.add),
                    label: const Text('Criar lote'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedBatch?.id,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text('Selecione um lote'),
                  items: _batches.map((b) {
                    return DropdownMenuItem<String>(
                      value: b.id,
                      child: Text(
                          '${b.name} (${b.items.length} série${b.items.length == 1 ? '' : 's'})'),
                    );
                  }).toList(),
                  onChanged: (id) {
                    setState(() {
                      _selectedBatch = _batches.firstWhere((b) => b.id == id);
                    });
                  },
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _selectedBatch != null ? _addToList : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '✓  Adicionar ao lote',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _discard,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('✕  Descartar e voltar'),
            ),
          ],
        ),
      ),
    );
  }
}
