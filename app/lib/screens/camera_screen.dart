import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/serial_item.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'confirm_screen.dart';
import 'list_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final List<SerialItem> sessionList;

  const CameraScreen({
    super.key,
    required this.cameras,
    required this.sessionList,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isProcessing = false;
  bool _cameraInitialized = false;
  bool _flashOn = false;
  late List<SerialItem> _sessionList;
  late ApiService _apiService;
  final StorageService _storageService = StorageService();
  String _sessionName = '';

  @override
  void initState() {
    super.initState();
    _sessionList = List.from(widget.sessionList);
    _apiService = ApiService(baseUrl: dotenv.env['BACKEND_URL']!);
    _initCamera();
    _loadPersistedSession();
  }

  Future<void> _loadPersistedSession() async {
    final session = await _storageService.loadSession();
    if (session != null && mounted) {
      setState(() {
        _sessionList = session.items;
        _sessionName = session.name;
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
          SnackBar(content: Text('Erro ao iniciar câmera: $e'), backgroundColor: Colors.red),
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

      final updatedList = await Navigator.push<List<SerialItem>>(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmScreen(
            serial: result['serial'] as String,
            confidence: result['confidence'] as String,
            sessionList: _sessionList,
            apiService: _apiService,
          ),
        ),
      );

      if (updatedList != null) {
        setState(() => _sessionList = updatedList);
        _storageService.saveSession(_sessionName, _sessionList);
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
              onTap: _openList,
              child: Chip(
                label: Text(
                  'Lista: ${_sessionList.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
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
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  ),
          ),
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                  label: Text(_isProcessing ? 'Processando...' : 'Fotografar'),
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
                  onPressed: _openList,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFF4F46E5)),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Ver lista →'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
