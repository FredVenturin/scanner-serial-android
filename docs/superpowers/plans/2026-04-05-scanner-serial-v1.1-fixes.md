# Scanner de Série v1.1 — Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 6 issues found during first field test — speed, flash, copy format, list persistence, duplicate alert, and email delivery.

**Architecture:** All changes are in the Flutter app (`app/`) except the email fix which is a Resend domain configuration + env variable update. No new backend code needed. Two new Flutter dependencies: `flutter_image_compress` for JPEG compression, `shared_preferences` for local persistence.

**Tech Stack:** Flutter/Dart, SharedPreferences, flutter_image_compress, Resend domain verification

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `app/pubspec.yaml` | Modify | Add `flutter_image_compress` and `shared_preferences` dependencies |
| `app/lib/models/serial_item.dart` | Modify | Add `fromMap()` factory, `toJson()`/`fromJson()` for persistence |
| `app/lib/services/storage_service.dart` | Create | SharedPreferences wrapper for list persistence |
| `app/lib/screens/camera_screen.dart` | Modify | Reduce resolution, compress image, add flash toggle, load persisted list |
| `app/lib/screens/list_screen.dart` | Modify | Session name field, "Nova lista" button, copy serials only, persist on changes |
| `app/lib/screens/confirm_screen.dart` | Modify | Duplicate serial alert dialog |
| `app/lib/services/api_service.dart` | Modify | Pass session name to export/email endpoints |
| `backend/.env` | Modify | Update EMAIL_FROM after domain verification |
| `app/test/models/serial_item_test.dart` | Modify | Tests for fromMap() |
| `app/test/services/storage_service_test.dart` | Create | Tests for StorageService |

---

### Task 1: Add Dependencies

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: Add flutter_image_compress and shared_preferences to pubspec.yaml**

In `app/pubspec.yaml`, add under `dependencies` (after the existing `path_provider` line):

```yaml
  shared_preferences: ^2.2.3
  flutter_image_compress: ^2.3.0
```

- [ ] **Step 2: Install dependencies**

Run:
```bash
cd app && flutter pub get
```

Expected: `Resolving dependencies...` followed by `Got dependencies!`

- [ ] **Step 3: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock
git commit -m "chore: add shared_preferences and flutter_image_compress dependencies"
```

---

### Task 2: Add fromMap() to SerialItem

**Files:**
- Modify: `app/lib/models/serial_item.dart`
- Modify: `app/test/models/serial_item_test.dart`

- [ ] **Step 1: Write the failing tests for fromMap()**

Add these tests at the end of the `group('SerialItem', ...)` block in `app/test/models/serial_item_test.dart`:

```dart
    test('fromMap cria item com serial e note', () {
      final map = {'serial': 'SN-100', 'note': 'Impressora', 'capturedAt': '2026-04-05T10:00:00.000'};
      final item = SerialItem.fromMap(map);
      expect(item.serial, 'SN-100');
      expect(item.note, 'Impressora');
      expect(item.capturedAt, DateTime.parse('2026-04-05T10:00:00.000'));
    });

    test('fromMap com note nulo', () {
      final map = {'serial': 'SN-200', 'capturedAt': '2026-04-05T10:00:00.000'};
      final item = SerialItem.fromMap(map);
      expect(item.serial, 'SN-200');
      expect(item.note, isNull);
    });

    test('toMap inclui capturedAt para persistencia', () {
      final item = SerialItem(serial: 'SN-300', capturedAt: DateTime.parse('2026-04-05T12:00:00.000'));
      final map = item.toFullMap();
      expect(map['serial'], 'SN-300');
      expect(map['capturedAt'], '2026-04-05T12:00:00.000');
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd app && flutter test test/models/serial_item_test.dart
```

Expected: FAIL — `fromMap` and `toFullMap` are not defined.

- [ ] **Step 3: Implement fromMap() and toFullMap()**

Replace the entire contents of `app/lib/models/serial_item.dart` with:

```dart
class SerialItem {
  final String serial;
  final String? note;
  final DateTime capturedAt;

  SerialItem({required this.serial, this.note, DateTime? capturedAt})
      : capturedAt = capturedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {'serial': serial, 'note': note};

  Map<String, dynamic> toFullMap() => {
        'serial': serial,
        'note': note,
        'capturedAt': capturedAt.toIso8601String(),
      };

  factory SerialItem.fromMap(Map<String, dynamic> map) {
    return SerialItem(
      serial: map['serial'] as String,
      note: map['note'] as String?,
      capturedAt: map['capturedAt'] != null
          ? DateTime.parse(map['capturedAt'] as String)
          : null,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd app && flutter test test/models/serial_item_test.dart
```

Expected: All 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/models/serial_item.dart app/test/models/serial_item_test.dart
git commit -m "feat: add fromMap() and toFullMap() to SerialItem for persistence"
```

---

### Task 3: Create StorageService

**Files:**
- Create: `app/lib/services/storage_service.dart`
- Create: `app/test/services/storage_service_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `app/test/services/storage_service_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd app && flutter test test/services/storage_service_test.dart
```

Expected: FAIL — `StorageService` not found.

- [ ] **Step 3: Implement StorageService**

Create `app/lib/services/storage_service.dart`:

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/serial_item.dart';

class SessionData {
  final String name;
  final List<SerialItem> items;

  SessionData({required this.name, required this.items});
}

class StorageService {
  static const _keyName = 'session_name';
  static const _keyItems = 'session_items';

  Future<void> saveSession(String name, List<SerialItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    final json = jsonEncode(items.map((i) => i.toFullMap()).toList());
    await prefs.setString(_keyItems, json);
  }

  Future<SessionData?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyName);
    final itemsJson = prefs.getString(_keyItems);

    if (name == null || itemsJson == null) return null;

    final List<dynamic> decoded = jsonDecode(itemsJson);
    final items = decoded
        .map((m) => SerialItem.fromMap(m as Map<String, dynamic>))
        .toList();

    return SessionData(name: name, items: items);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
    await prefs.remove(_keyItems);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd app && flutter test test/services/storage_service_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/storage_service.dart app/test/services/storage_service_test.dart
git commit -m "feat: add StorageService for local list persistence"
```

---

### Task 4: Speed — Reduce Resolution and Compress Image

**Files:**
- Modify: `app/lib/screens/camera_screen.dart`

- [ ] **Step 1: Change resolution from high to medium**

In `app/lib/screens/camera_screen.dart`, line 43, change:

```dart
      ResolutionPreset.high,
```

to:

```dart
      ResolutionPreset.medium,
```

- [ ] **Step 2: Add import for flutter_image_compress**

Add at the top of `app/lib/screens/camera_screen.dart`, after the existing imports:

```dart
import 'package:flutter_image_compress/flutter_image_compress.dart';
```

- [ ] **Step 3: Add image compression before sending to backend**

In `app/lib/screens/camera_screen.dart`, replace lines 68-70 (inside `_takePicture()`):

```dart
      final image = await _controller.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
```

with:

```dart
      final image = await _controller.takePicture();
      final bytes = await image.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      final base64Image = base64Encode(compressed);
```

- [ ] **Step 4: Run app to verify it compiles**

Run:
```bash
cd app && flutter build apk --debug 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL` (no compilation errors).

- [ ] **Step 5: Commit**

```bash
git add app/lib/screens/camera_screen.dart
git commit -m "perf: reduce camera resolution and compress JPEG to 70% quality"
```

---

### Task 5: Flash — Toggle Button

**Files:**
- Modify: `app/lib/screens/camera_screen.dart`

- [ ] **Step 1: Add flash state variable**

In `app/lib/screens/camera_screen.dart`, add after line 27 (`bool _cameraInitialized = false;`):

```dart
  bool _flashOn = false;
```

- [ ] **Step 2: Add flash toggle method**

Add this method after the `_initCamera()` method (after line 55):

```dart
  Future<void> _toggleFlash() async {
    if (!_cameraInitialized) return;
    _flashOn = !_flashOn;
    await _controller.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }
```

- [ ] **Step 3: Add flash button to AppBar**

In `app/lib/screens/camera_screen.dart`, in the `actions` list of the AppBar (before the existing `Padding` with the list chip), add:

```dart
          IconButton(
            icon: Icon(
              _flashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: _toggleFlash,
          ),
```

- [ ] **Step 4: Run app to verify it compiles**

Run:
```bash
cd app && flutter build apk --debug 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Commit**

```bash
git add app/lib/screens/camera_screen.dart
git commit -m "feat: add flash toggle button on camera screen"
```

---

### Task 6: Copy Serials — Only Numbers

**Files:**
- Modify: `app/lib/screens/list_screen.dart`

- [ ] **Step 1: Replace _copyAll() method**

In `app/lib/screens/list_screen.dart`, replace the entire `_copyAll()` method (lines 39-48):

```dart
  void _copyAll() {
    final text = _list.asMap().entries.map((e) {
      final note = e.value.note != null ? ' — ${e.value.note}' : '';
      return '${e.key + 1}. ${e.value.serial}$note';
    }).join('\n');

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lista copiada para a área de transferência!')),
    );
  }
```

with:

```dart
  void _copyAll() {
    final text = _list.map((e) => e.serial).join('\n');

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seriais copiados para a área de transferência!')),
    );
  }
```

- [ ] **Step 2: Commit**

```bash
git add app/lib/screens/list_screen.dart
git commit -m "fix: copy only serial numbers without numbering or notes"
```

---

### Task 7: Duplicate Serial Alert

**Files:**
- Modify: `app/lib/screens/confirm_screen.dart`

- [ ] **Step 1: Replace _addToList() method with duplicate check**

In `app/lib/screens/confirm_screen.dart`, replace the entire `_addToList()` method (lines 43-61):

```dart
  void _addToList() {
    final serial = _serialController.text.trim();
    if (serial.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite o número de série antes de adicionar.'),
        ),
      );
      return;
    }

    final note = _noteController.text.trim();
    final newItem = SerialItem(
      serial: serial,
      note: note.isEmpty ? null : note,
    );

    final updatedList = [...widget.sessionList, newItem];
    Navigator.pop(context, updatedList);
  }
```

with:

```dart
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

    final isDuplicate = widget.sessionList.any(
      (item) => item.serial.trim().toLowerCase() == serial.toLowerCase(),
    );

    if (isDuplicate) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Série duplicada'),
          content: Text('O serial "$serial" já está na lista. Deseja adicionar mesmo assim?'),
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
    }

    final note = _noteController.text.trim();
    final newItem = SerialItem(
      serial: serial,
      note: note.isEmpty ? null : note,
    );

    final updatedList = [...widget.sessionList, newItem];
    Navigator.pop(context, updatedList);
  }
```

- [ ] **Step 2: Run app to verify it compiles**

Run:
```bash
cd app && flutter build apk --debug 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
git add app/lib/screens/confirm_screen.dart
git commit -m "feat: alert when adding duplicate serial number"
```

---

### Task 8: List Persistence and Session Name

**Files:**
- Modify: `app/lib/screens/camera_screen.dart`
- Modify: `app/lib/screens/list_screen.dart`

This is the largest task. It wires the StorageService from Task 3 into both screens.

- [ ] **Step 1: Update CameraScreen to load persisted session on start**

In `app/lib/screens/camera_screen.dart`, add import at the top:

```dart
import '../services/storage_service.dart';
```

Add a new field after `late ApiService _apiService;` (line 29):

```dart
  final StorageService _storageService = StorageService();
  String _sessionName = '';
```

In `initState()`, after the line `_apiService = ApiService(baseUrl: dotenv.env['BACKEND_URL']!);`, add:

```dart
    _loadPersistedSession();
```

Add a new method after `_initCamera()`:

```dart
  Future<void> _loadPersistedSession() async {
    final session = await _storageService.loadSession();
    if (session != null && mounted) {
      setState(() {
        _sessionList = session.items;
        _sessionName = session.name;
      });
    }
  }
```

- [ ] **Step 2: Pass sessionName through navigation and persist on update**

In `_takePicture()`, after `setState(() => _sessionList = updatedList);` (line 89), add:

```dart
        _storageService.saveSession(_sessionName, _sessionList);
```

- [ ] **Step 3: Update ListScreen to pass sessionName and persist**

In `app/lib/screens/list_screen.dart`, add import at the top:

```dart
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
```

Wait — `intl` is not in dependencies. Use a simpler date format instead. Replace the import above with just:

```dart
import '../services/storage_service.dart';
```

Add `sessionName` parameter to ListScreen constructor. Replace the ListScreen class definition and its fields (lines 8-19):

```dart
class ListScreen extends StatefulWidget {
  final List<SerialItem> sessionList;
  final ApiService apiService;
  final String sessionName;
  final void Function(List<SerialItem> list, String name) onListUpdated;

  const ListScreen({
    super.key,
    required this.sessionList,
    required this.apiService,
    required this.sessionName,
    required this.onListUpdated,
  });

  @override
  State<ListScreen> createState() => _ListScreenState();
}
```

- [ ] **Step 4: Add session name state and StorageService to _ListScreenState**

Replace the `_ListScreenState` class fields and `initState()` (lines 24-32):

```dart
class _ListScreenState extends State<ListScreen> {
  late List<SerialItem> _list;
  late TextEditingController _nameController;
  final StorageService _storageService = StorageService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.sessionList);
    final defaultName = 'Lista ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';
    _nameController = TextEditingController(
      text: widget.sessionName.isEmpty ? defaultName : widget.sessionName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
```

- [ ] **Step 5: Add persist helper and update _removeItem()**

Add this method and update `_removeItem`:

```dart
  void _persist() {
    widget.onListUpdated(_list, _nameController.text);
    _storageService.saveSession(_nameController.text, _list);
  }

  void _removeItem(int index) {
    setState(() => _list.removeAt(index));
    _persist();
  }
```

- [ ] **Step 6: Add "Nova lista" method**

Add this method after `_removeItem()`:

```dart
  Future<void> _newList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova lista'),
        content: const Text('Tem certeza? A lista atual será apagada.'),
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
            child: const Text('Apagar e criar nova'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _storageService.clearSession();
    setState(() {
      _list.clear();
      _nameController.text = 'Lista ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';
    });
    _persist();
  }
```

- [ ] **Step 7: Update _downloadFile to use session name**

In `_downloadFile()`, change the file save line from:

```dart
      final file = File('${dir.path}/seriais.$format');
```

to:

```dart
      final safeName = _nameController.text.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
      final fileName = safeName.isEmpty ? 'seriais' : safeName;
      final file = File('${dir.path}/$fileName.$format');
```

- [ ] **Step 8: Add session name field and "Nova lista" button to the UI**

In the `build()` method, add the session name field and "Nova lista" button. Replace the body of the `Scaffold` (everything inside `body:`) with:

```dart
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  color: Colors.white,
                  child: TextField(
                    controller: _nameController,
                    onChanged: (_) => _persist(),
                    decoration: InputDecoration(
                      labelText: 'Nome da sessão',
                      hintText: 'Ex: Sala 3 - 05/04',
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.red),
                        tooltip: 'Nova lista',
                        onPressed: _newList,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _list.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum serial escaneado ainda.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _list.length,
                          itemBuilder: (_, i) {
                            final item = _list[i];
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
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
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
                      top: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _list.isEmpty ? null : _showDownloadOptions,
                        icon: const Icon(Icons.download),
                        label: const Text('Baixar arquivo (PDF / XLSX / TXT / DOC)'),
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
                      ElevatedButton.icon(
                        onPressed: _list.isEmpty ? null : _sendEmail,
                        icon: const Icon(Icons.email_outlined),
                        label: const Text('Enviar por e-mail'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF0FDF4),
                          foregroundColor: const Color(0xFF16A34A),
                          minimumSize: const Size(double.infinity, 46),
                          side: const BorderSide(color: Color(0xFF86EFAC)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _list.isEmpty ? null : _copyAll,
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
```

- [ ] **Step 9: Update CameraScreen._openList() to pass sessionName and handle updated callback**

In `app/lib/screens/camera_screen.dart`, replace the `_openList()` method:

```dart
  void _openList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListScreen(
          sessionList: _sessionList,
          apiService: _apiService,
          sessionName: _sessionName,
          onListUpdated: (list, name) {
            setState(() {
              _sessionList = list;
              _sessionName = name;
            });
          },
        ),
      ),
    );
  }
```

- [ ] **Step 10: Run app to verify it compiles**

Run:
```bash
cd app && flutter build apk --debug 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 11: Commit**

```bash
git add app/lib/screens/camera_screen.dart app/lib/screens/list_screen.dart
git commit -m "feat: add session name field, local persistence, and 'Nova lista' button"
```

---

### Task 9: Email — Configure Resend Domain

This task is a manual configuration — no code changes beyond updating the env variable.

- [ ] **Step 1: Add domain in Resend**

Go to https://resend.com/domains → Click "Add Domain" → Enter your company domain (e.g. `empresa.com.br`) → Follow the DNS instructions:

1. Add the **MX record** Resend provides to your DNS
2. Add the **TXT record** (SPF) to your DNS
3. Add the **DKIM records** (3 CNAME records) to your DNS
4. Wait for verification (can take up to 72 hours, usually minutes)

- [ ] **Step 2: Update EMAIL_FROM in Railway**

In Railway → service → Variables → change:
```
EMAIL_FROM=scanner@empresa.com.br
```
(Replace `empresa.com.br` with your actual domain)

- [ ] **Step 3: Update local .env**

In `backend/.env`, update:
```
EMAIL_FROM=scanner@empresa.com.br
```

- [ ] **Step 4: Test email delivery**

Use the app to send an email to an external address. Verify it arrives in the inbox (not spam).

- [ ] **Step 5: Commit .env change**

Note: `.env` is in `.gitignore` so no commit needed. Just verify Railway variable is updated.

---

### Task 10: Build and Deploy

- [ ] **Step 1: Push all changes to GitHub**

```bash
git push
```

Railway will auto-deploy from the push.

- [ ] **Step 2: Build release APK**

```bash
cd app && flutter build apk --release
```

The APK will be at `app/build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 3: Distribute APK to employees**

Send the new `app-release.apk` to employees. They install over the existing version — no need to uninstall first.

- [ ] **Step 4: Verify all fixes on physical device**

Test checklist on a real phone:
1. Speed: take a photo — should respond noticeably faster
2. Flash: toggle flash on/off in dark environment
3. Copy: copy serials — should be clean numbers only, one per line
4. Duplicate: try adding same serial twice — should show warning dialog
5. Persistence: add serials → close app → reopen → list should be preserved
6. Session name: set a name → export file → file should use that name
7. Email: send to an external address → should arrive in inbox
