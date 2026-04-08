# Scanner de Série

App Android interno para funcionários escanearem números de série de equipamentos via câmera, organizando os resultados em lotes nomeados com exportação de arquivo.

---

## Visão Geral

O sistema consiste em um app Flutter (Android) e um backend Node.js hospedado no Railway. O funcionário fotografa a etiqueta do equipamento, o backend extrai o número de série via OCR + IA, e o usuário confirma e salva em um lote.

---

## Arquitetura

```
App Flutter (Android APK)
    │
    ├── POST /scan        →  Backend Node.js (Railway)
    │                            ├── Google Cloud Vision (OCR)
    │                            └── Claude Haiku (identificação do serial)
    │
    └── POST /export      →  Backend Node.js (Railway)
                                 └── Geração de PDF / XLSX / TXT / DOCX
```

---

## App Flutter

### Telas

| Tela | Descrição |
|---|---|
| `CameraScreen` | Tela principal. Câmera com viewfinder, botão Fotografar e botão Ver lotes |
| `ConfirmScreen` | Exibe o serial detectado (editável), campo de observação e seletor de lote |
| `BatchListScreen` | Lista de lotes com criação, edição e exclusão |
| `BatchDetailScreen` | Seriais de um lote com download e cópia |

### Fluxo

```
CameraScreen → Fotografar → ConfirmScreen → seleciona lote → CameraScreen
CameraScreen → Ver lotes → BatchListScreen → toca no lote → BatchDetailScreen
```

### Modelos

```dart
// Lote
class Batch {
  final String id;        // UUID v4
  final String name;      // max 30 chars
  final DateTime createdAt;
  final List<SerialItem> items;
}

// Serial
class SerialItem {
  final String serial;
  final String? note;
  final DateTime capturedAt;
}
```

### Regras de negócio

- Máximo de **5 lotes** simultâneos
- Sem limite de seriais por lote
- Verificação de duplicata em **todos os lotes** antes de inserir
- Último lote usado é pré-selecionado automaticamente no ConfirmScreen
- Exportação usa o nome do lote como nome do arquivo

### Persistência

`SharedPreferences` — os lotes e o último lote usado ficam salvos localmente no dispositivo entre sessões.

### Dependências principais

| Pacote | Uso |
|---|---|
| `camera` | Acesso à câmera |
| `flutter_image_compress` | Compressão JPEG antes de enviar |
| `shared_preferences` | Persistência local |
| `uuid` | Geração de IDs únicos para lotes |
| `flutter_dotenv` | Leitura do `.env` com a URL do backend |
| `path_provider` | Caminho para salvar arquivos temporários |

### Configuração

Criar `app/.env`:

```
BACKEND_URL=https://sua-url.up.railway.app
```

### Build do APK

```bash
cd app
flutter pub get
flutter build apk --release
# APK gerado em: build/app/outputs/flutter-apk/app-release.apk
```

---

## Backend Node.js

Hospedado no **Railway** com deploy automático via GitHub.

### Rotas

| Método | Rota | Descrição |
|---|---|---|
| `POST` | `/scan` | Recebe imagem base64, retorna serial e confiança |
| `POST` | `/export/:format` | Recebe lista de seriais, retorna arquivo (pdf/xlsx/txt/docx) |

### Pipeline de OCR

1. Recebe imagem em base64
2. Envia para **Google Cloud Vision** — extrai texto bruto
3. Envia texto para **Claude Haiku** — identifica o número de série
4. Retorna `{ serial, confidence }` para o app

### Dependências principais

| Pacote | Uso |
|---|---|
| `express` | Servidor HTTP |
| `@google-cloud/vision` | OCR |
| `@anthropic-ai/sdk` | Claude Haiku para identificação do serial |
| `pdfkit` | Geração de PDF |
| `exceljs` | Geração de XLSX |
| `docx` | Geração de DOCX |

### Variáveis de ambiente (Railway)

```
ANTHROPIC_API_KEY=...
GOOGLE_APPLICATION_CREDENTIALS_JSON=...   # conteúdo do google-key.json
PORT=3000
```

### Rodar localmente

```bash
cd backend
npm install
npm run dev
```

### Testes

```bash
cd backend
npm test
```

---

## Estrutura de arquivos

```
projeto - Serial/
├── app/                        # Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   │   ├── batch.dart
│   │   │   └── serial_item.dart
│   │   ├── screens/
│   │   │   ├── camera_screen.dart
│   │   │   ├── confirm_screen.dart
│   │   │   ├── batch_list_screen.dart
│   │   │   └── batch_detail_screen.dart
│   │   └── services/
│   │       ├── api_service.dart
│   │       └── storage_service.dart
│   ├── test/
│   │   ├── models/batch_test.dart
│   │   └── services/storage_service_test.dart
│   └── pubspec.yaml
├── backend/                    # Node.js
│   ├── index.js
│   ├── routes/
│   │   ├── scan.js
│   │   └── export.js
│   └── services/
│       ├── ocr.js
│       ├── claude.js
│       └── exporter.js
├── docs/
│   └── superpowers/
│       ├── specs/              # Design docs
│       └── plans/             # Planos de implementação
└── railway.toml               # Configuração de deploy
```

---

## Histórico de versões

### v1.2 — Sistema de Lotes
- Substituição da lista única por sistema de múltiplos lotes (máx. 5)
- Criação, edição e exclusão de lotes por nome
- Seletor de lote na tela de confirmação com pré-seleção do último usado
- Verificação de duplicata entre todos os lotes
- `BatchListScreen` e `BatchDetailScreen` — novas telas
- `StorageService` reescrito para gerenciar `List<Batch>`
- Exportação de arquivo usa nome do lote como nome do arquivo

### v1.1 — Melhorias de campo
- Compressão de imagem antes do envio (JPEG 70%)
- Toggle de flash
- Persistência da sessão entre aberturas do app
- Campo de observação por serial
- Alerta de duplicata
- Cópia de seriais para área de transferência
- Nome da sessão editável

### v1.0 — MVP
- Câmera + OCR + Claude Haiku
- Lista de seriais com exportação (PDF, XLSX, TXT, DOCX)
- Backend Node.js no Railway
