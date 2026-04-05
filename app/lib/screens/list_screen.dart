import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/serial_item.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

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

class _ListScreenState extends State<ListScreen> {
  late List<SerialItem> _list;
  late TextEditingController _nameController;
  final StorageService _storageService = StorageService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.sessionList);
    final now = DateTime.now();
    final defaultName = 'Lista ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    _nameController = TextEditingController(
      text: widget.sessionName.isEmpty ? defaultName : widget.sessionName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _persist() {
    widget.onListUpdated(_list, _nameController.text);
    _storageService.saveSession(_nameController.text, _list);
  }

  void _removeItem(int index) {
    setState(() => _list.removeAt(index));
    _persist();
  }

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

    if (confirmed != true || !mounted) return;

    await _storageService.clearSession();
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _list.clear();
      _nameController.text = 'Lista ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    });
    _persist();
  }

  void _copyAll() {
    final text = _list.map((e) => e.serial).join('\n');

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seriais copiados para a área de transferência!')),
    );
  }

  Future<void> _downloadFile(String format) async {
    setState(() => _isLoading = true);
    try {
      final bytes = await widget.apiService.exportFile(format, _list);
      final dir = await getTemporaryDirectory();
      final safeName = _nameController.text.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
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

  Future<void> _sendEmail() async {
    String? emailTo;
    String selectedMode = 'text';
    String selectedFormat = 'pdf';

    await showDialog(
      context: context,
      builder: (ctx) {
        final emailCtrl = TextEditingController();
        String dialogMode = 'text';
        String dialogFormat = 'pdf';

        return StatefulBuilder(builder: (ctx, setInner) {
          return AlertDialog(
            title: const Text('Enviar por e-mail'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail de destino',
                      hintText: 'funcionario@empresa.com',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Modo de envio:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  RadioGroup<String>(
                    groupValue: dialogMode,
                    onChanged: (v) => setInner(() => dialogMode = v!),
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          title: Text('Texto no corpo do e-mail'),
                          value: 'text',
                          dense: true,
                        ),
                        RadioListTile<String>(
                          title: Text('Arquivo em anexo'),
                          value: 'attachment',
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                  if (dialogMode == 'attachment') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: dialogFormat,
                      decoration: const InputDecoration(labelText: 'Formato'),
                      items: ['pdf', 'xlsx', 'txt', 'docx']
                          .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(f.toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (v) => setInner(() => dialogFormat = v!),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  emailTo = emailCtrl.text.trim();
                  selectedMode = dialogMode;
                  selectedFormat = dialogFormat;
                  Navigator.pop(ctx);
                },
                child: const Text('Enviar'),
              ),
            ],
          );
        });
      },
    );

    if (emailTo == null || emailTo!.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await widget.apiService.sendEmail(
        emailTo!,
        selectedMode,
        selectedMode == 'attachment' ? selectedFormat : null,
        _list,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('E-mail enviado para $emailTo!')),
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
        title: const Text(
          'Lista de Seriais',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(
                '${_list.length} itens',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: Colors.white24,
            ),
          ),
        ],
      ),
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
    );
  }
}
