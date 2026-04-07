# Sistema de Lotes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir o sistema de lista única por sistema de lotes múltiplos (máximo 5), com gerenciamento completo e verificação de duplicatas entre todos os lotes.

**Architecture:** Novo modelo `Batch` com UUID, nome e lista de `SerialItem`. `StorageService` reescrito para gerenciar `List<Batch>` + último lote usado. Três telas novas/modificadas: `BatchListScreen`, `BatchDetailScreen`, `ConfirmScreen` (com seletor de lote). `ListScreen` removida.

**Tech Stack:** Flutter/Dart, SharedPreferences, pacote `uuid` para geração de IDs únicos.

---

## File Map

| Arquivo | Ação | Responsabilidade |
|---|---|---|
| `app/pubspec.yaml` | Modify | Adicionar dependência `uuid` |
| `app/lib/models/batch.dart` | Create | Modelo Batch com serialização |
| `app/lib/services/storage_service.dart` | Rewrite | Gerenciar List<Batch> + last_batch_id |
| `app/lib/screens/batch_list_screen.dart` | Create | Tela de lista de lotes |
| `app/lib/screens/batch_detail_screen.dart` | Create | Tela de séries de um lote |
| `app/lib/screens/confirm_screen.dart` | Modify | Adicionar seletor de lote |
| `app/lib/screens/camera_screen.dart` | Modify | Chip "Lotes: N | Séries: T", navegar para BatchListScreen |
| `app/lib/screens/list_screen.dart` | Delete | Substituída pelas novas telas |
| `app/test/models/batch_test.dart` | Create | Testes do modelo Batch |
| `app/test/services/storage_service_test.dart` | Rewrite | Testes do novo StorageService |

---

### Task 1: Add uuid dependency

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: Add uuid to pubspec.yaml**

In `app/pubspec.yaml`, add under `dependencies:` after `flutter_image_compress: ^2.3.0`:

```yaml
  uuid: ^4.5.1
```

- [ ] **Step 2: Install dependency**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial/app" && flutter pub get
```

Expected: `Got dependencies!`

- [ ] **Step 3: Commit**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial" && git add app/pubspec.yaml app/pubspec.lock && git commit -m "chore: add uuid dependency"
```

---

### Task 2: Create Batch model

**Files:**
- Create: `app/lib/models/batch.dart`
- Create: `app/test/models/batch_test.dart`

- [ ] **Step 1: Write failing tests**

Create `app/test/models/batch_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_serial/models/batch.dart';
import 'package:scanner_serial/models/serial_item.dart';

void main() {
  group('Batch', () {
    test('toMap e fromMap preservam todos os campos', () {
      final item = SerialItem(
        serial: 'SN-001',
        note: 'Dell',
        capturedAt: DateTime.parse('2026-04-07T10:00:00.000'),
      );
      final batch = Batch(
        id: 'abc-123',
        name: 'Sala 3',
        createdAt: DateTime.parse('2026-04-07T09:00:00.000'),
        items: [item],
      );

      final map = batch.toMap();
      final restored = Batch.fromMap(map);

      expect(restored.id, 'abc-123');
      expect(restored.name, 'Sala 3');
      expect(restored.createdAt, DateTime.parse('2026-04-07T09:00:00.000'));
      expect(restored.items.length, 1);
      expect(restored.items[0].serial, 'SN-001');
      expect(restored.items[0].note, 'Dell');
    });

    test('fromMap com items vazio', () {
      final batch = Batch(
        id: 'xyz-456',
        name: 'Andar 2',
        createdAt: DateTime.parse('2026-04-07T09:00:00.000'),
        items: [],
      );
      final restored = Batch.fromMap(batch.toMap());
      expect(restored.items, isEmpty);
    });

    test('copyWith atualiza apenas os campos fornecidos', () {
      final batch = Batch(
        id: 'abc-123',
        name: 'Sala 3',
        createdAt: DateTime.parse('2026-04-07T09:00:00.000'),
        items: [],
      );
      final updated = batch.copyWith(name: 'Sala 4');
      expect(updated.id, 'abc-123');
      expect(updated.name, 'Sala 4');
      expect(updated.createdAt, batch.createdAt);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial/app" && flutter test test/models/batch_test.dart
```

Expected: FAIL — `Batch` not found.

- [ ] **Step 3: Implement Batch model**

Create `app/lib/models/batch.dart`:

```dart
import 'serial_item.dart';

class Batch {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<SerialItem> items;

  Batch({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.items,
  });

  Batch copyWith({String? name, List<SerialItem>? items}) {
    return Batch(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'items': items.map((i) => i.toFullMap()).toList(),
      };

  factory Batch.fromMap(Map<String, dynamic> map) {
    return Batch(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      items: (map['items'] as List<dynamic>)
          .map((i) => SerialItem.fromMap(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial/app" && flutter test test/models/batch_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial" && git add app/lib/models/batch.dart app/test/models/batch_test.dart && git commit -m "feat: add Batch model with serialization and copyWith"
```

---

### Task 3: Rewrite StorageService

**Files:**
- Rewrite: `app/lib/services/storage_service.dart`
- Rewrite: `app/test/services/storage_service_test.dart`

- [ ] **Step 1: Write failing tests**

Replace contents of `app/test/services/storage_service_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial/app" && flutter test test/services/storage_service_test.dart
```

Expected: FAIL — methods not found.

- [ ] **Step 3: Rewrite StorageService**

Replace entire contents of `app/lib/services/storage_service.dart`:

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/batch.dart';

class StorageService {
  static const _keyBatches = 'batches';
  static const _keyLastBatchId = 'last_batch_id';

  Future<void> saveBatches(List<Batch> batches) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(batches.map((b) => b.toMap()).toList());
    await prefs.setString(_keyBatches, json);
  }

  Future<List<Batch>> loadBatches() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyBatches);
    if (json == null) return [];
    final List<dynamic> decoded = jsonDecode(json);
    return decoded.map((m) => Batch.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<void> saveLastBatchId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBatchId, id);
  }

  Future<String?> loadLastBatchId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastBatchId);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBatches);
    await prefs.remove(_keyLastBatchId);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial/app" && flutter test test/services/storage_service_test.dart
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial" && git add app/lib/services/storage_service.dart app/test/services/storage_service_test.dart && git commit -m "feat: rewrite StorageService to manage List<Batch>"
```

---

### Task 4: Create BatchListScreen

**Files:**
- Create: `app/lib/screens/batch_list_screen.dart`

- [ ] **Step 1: Create BatchListScreen**

Create `app/lib/screens/batch_list_screen.dart`:

```dart
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
    final updatedBatch = await Navigator.push<Batch>(
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
    if (updatedBatch != null && mounted) {
      setState(() => _batches[index] = updatedBatch);
      _persist();
    }
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
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
```

- [ ] **Step 2: Verify it compiles**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial/app" && flutter analyze lib/screens/batch_list_screen.dart 2>&1 | tail -5
```

Expected: `No issues found!` (BatchDetailScreen not yet created — may show import error, which is expected at this stage)

- [ ] **Step 3: Commit**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial" && git add app/lib/screens/batch_list_screen.dart && git commit -m "feat: add BatchListScreen with create/edit/delete batch"
```

---

### Task 5: Create BatchDetailScreen

**Files:**
- Create: `app/lib/screens/batch_detail_screen.dart`

- [ ] **Step 1: Create BatchDetailScreen**

Create `app/lib/screens/batch_detail_screen.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/batch.dart';
import '../models/serial_item.dart';
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
                        onPressed:
                            _batch.items.isEmpty ? null : _copyAll,
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
```

- [ ] **Step 2: Verify it compiles**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial/app" && flutter analyze lib/screens/batch_detail_screen.dart 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial" && git add app/lib/screens/batch_detail_screen.dart && git commit -m "feat: add BatchDetailScreen with list, download, and copy"
```

---

### Task 6: Update ConfirmScreen

**Files:**
- Modify: `app/lib/screens/confirm_screen.dart`

Replace the entire file with the new version that includes batch selector:

- [ ] **Step 1: Replace confirm_screen.dart**

Replace entire contents of `app/lib/screens/confirm_screen.dart`:

```dart
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

    // Pre-select last used batch
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
              DropdownButtonFormField<String>(
                value: _selectedBatch?.id,
                decoration: InputDecoration(
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
```

- [ ] **Step 2: Verify it compiles**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial/app" && flutter analyze lib/screens/confirm_screen.dart 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial" && git add app/lib/screens/confirm_screen.dart && git commit -m "feat: add batch selector to ConfirmScreen with cross-batch duplicate check"
```

---

### Task 7: Update CameraScreen

**Files:**
- Modify: `app/lib/screens/camera_screen.dart`

- [ ] **Step 1: Read current camera_screen.dart**

Read `app/lib/screens/camera_screen.dart` to understand current state before making changes.

- [ ] **Step 2: Replace camera_screen.dart**

Replace entire contents of `app/lib/screens/camera_screen.dart`:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/batch.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'confirm_screen.dart';
import 'batch_list_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({
    super.key,
    required this.cameras,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isProcessing = false;
  bool _cameraInitialized = false;
  bool _flashOn = false;
  List<Batch> _batches = [];
  String? _lastBatchId;
  late ApiService _apiService;
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: dotenv.env['BACKEND_URL']!);
    _initCamera();
    _loadPersistedData();
  }

  Future<void> _loadPersistedData() async {
    final batches = await _storageService.loadBatches();
    final lastId = await _storageService.loadLastBatchId();
    if (mounted) {
      setState(() {
        _batches = batches;
        _lastBatchId = lastId;
      });
    }
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
    );
    try {
      await _controller.initialize();
      if (mounted) setState(() => _cameraInitialized = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao iniciar câmera: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (!_cameraInitialized) return;
    _flashOn = !_flashOn;
    await _controller.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  @override
  void dispose() {
    if (_cameraInitialized) _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_isProcessing || !_cameraInitialized) return;
    setState(() => _isProcessing = true);

    try {
      final image = await _controller.takePicture();
      final bytes = await image.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      final base64Image = base64Encode(compressed);

      final result = await _apiService.scanImage(base64Image);

      if (!mounted) return;

      final updatedBatches = await Navigator.push<List<Batch>>(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmScreen(
            serial: result['serial'] as String,
            confidence: result['confidence'] as String,
            batches: _batches,
            lastBatchId: _lastBatchId,
          ),
        ),
      );

      if (updatedBatches != null && mounted) {
        setState(() => _batches = updatedBatches);
        await _storageService.saveBatches(_batches);
        final lastId = await _storageService.loadLastBatchId();
        if (mounted) setState(() => _lastBatchId = lastId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openBatchList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BatchListScreen(
          batches: _batches,
          apiService: _apiService,
          onBatchesUpdated: (batches) {
            setState(() => _batches = batches);
            _storageService.saveBatches(batches);
          },
        ),
      ),
    );
  }

  int get _totalSerials =>
      _batches.fold(0, (sum, b) => sum + b.items.length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        title: const Text(
          'Scanner de Série',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _flashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: _toggleFlash,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openBatchList,
              child: Chip(
                label: Text(
                  'Lotes: ${_batches.length} | Séries: $_totalSerials',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _cameraInitialized
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_controller),
                      Center(
                        child: Container(
                          width: 260,
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF4F46E5),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Text(
                          'Aponte para a etiqueta do equipamento',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF4F46E5)),
                  ),
          ),
          Container(
            color: Colors.black87,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _takePicture,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(
                      _isProcessing ? 'Processando...' : 'Fotografar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _openBatchList,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFF4F46E5)),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Ver lotes →'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Update main.dart** — CameraScreen no longer takes `sessionList` parameter

Replace entire contents of `app/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:camera/camera.dart';
import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  final cameras = await availableCameras();
  runApp(ScannerApp(cameras: cameras));
}

class ScannerApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const ScannerApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner de Série',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: CameraScreen(cameras: cameras),
    );
  }
}
```

- [ ] **Step 4: Delete list_screen.dart**

```bash
rm "c:/Users/Frederico/Desktop/projeto - Serial/app/lib/screens/list_screen.dart"
```

- [ ] **Step 5: Verify full app compiles**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial/app" && flutter analyze && flutter build apk --debug 2>&1 | tail -5
```

Expected: `No issues found!` and `BUILD SUCCESSFUL`

- [ ] **Step 6: Commit**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial" && git add -A && git commit -m "feat: wire batch system into CameraScreen, remove ListScreen"
```

---

### Task 8: Build release APK and push

- [ ] **Step 1: Build release APK**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial/app" && flutter build apk --release 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 2: Push to GitHub**

```bash
cd "c:/Users/Frederico/Desktop/projeto - Serial" && git push
```

Expected: `Everything up-to-date` or push confirmation.
