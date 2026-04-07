# Design: Scanner de Número de Série
**Data:** 2026-04-03  
**Status:** Aprovado

---

## 1. Objetivo

Aplicativo Android interno (distribuído por APK) que permite funcionários fotografar equipamentos e obter automaticamente o número de série presente na imagem, via análise de foto com OCR + IA. O funcionário pode acumular múltiplos seriais numa sessão e ao final exportar a lista como arquivo ou receber por e-mail.

---

## 2. Arquitetura Geral

```
App Flutter (APK)
  Tela 1: Câmera → Tela 2: Confirmação → Tela 3: Lista & Exportação
        │
        │ HTTPS
        ▼
Backend Node.js (Railway)
  POST /scan    → Cloud Vision → Claude Haiku → retorna serial
  POST /export  → gera arquivo → retorna download
  POST /email   → gera arquivo ou texto → Resend → envia e-mail
        │                          │
        ▼                          ▼
 Google Cloud Vision          Resend.com
 + Claude Haiku API
```

**Princípio central:** o app Flutter é responsável apenas por captura, exibição e armazenamento temporário da lista em memória. Toda lógica pesada (OCR, IA, geração de arquivo, e-mail) fica no backend.

---

## 3. Fluxo da Aplicação

1. Funcionário abre o app → câmera já está ativa
2. Fotografa o equipamento (foto comum — sem leitor de código de barras)
3. App envia imagem em base64 ao backend (`POST /scan`)
4. Backend chama Google Cloud Vision → extrai todo o texto da imagem
5. Texto extraído é enviado ao Claude Haiku → retorna apenas o número de série
6. App exibe serial na tela de confirmação (editável)
7. Funcionário adiciona observação opcional e confirma
8. Serial é adicionado à lista em memória → app volta automaticamente à câmera
9. Repete para cada equipamento
10. Ao terminar, funcionário abre a lista e escolhe exportar

---

## 4. Telas

### Tela 1 — Câmera
- Câmera sempre aberta ao entrar na tela
- Guia visual simples de câmera (sem estilo leitor de barras)
- Botão "Fotografar" — captura a foto e navega para Tela 2
- Botão "Ver lista" com badge mostrando quantidade de seriais acumulados
- Design: fundo escuro na área da câmera, header roxo (#4f46e5)

### Tela 2 — Confirmação
- Exibe o serial detectado pelo Claude em destaque (fonte monospace)
- Campo editável: funcionário pode corrigir o serial se necessário
- Campo de observação opcional (ex: "Notebook Dell — Sala 3")
- Botão "Adicionar à lista" → adiciona e volta à Tela 1 automaticamente
- Botão "Descartar e voltar" → descarta sem adicionar
- Indicação visual de confiança caso Claude retorne `SERIAL_NAO_ENCONTRADO`

### Tela 3 — Lista & Exportação
- Lista de todos os seriais da sessão com observações
- Cada item tem botão de remoção individual
- Três ações de exportação:
  - **Baixar arquivo** — escolhe formato (PDF / XLSX / TXT / DOCX) → download direto no celular
  - **Enviar por e-mail** — escolhe modo (arquivo anexo ou texto no corpo) → digita e-mail → envia
  - **Copiar todos** — copia lista completa para área de transferência

---

## 5. Backend — Rotas

### `POST /scan`
```json
// Entrada
{ "image": "base64string..." }

// Saída
{ "serial": "SN-00X7482K", "confidence": "high" }
// ou
{ "serial": "SERIAL_NAO_ENCONTRADO", "confidence": "low" }
```

### `POST /export`
```json
// Entrada
{
  "format": "pdf" | "xlsx" | "txt" | "docx",
  "serials": [
    { "serial": "SN-00X7482K", "note": "Notebook Dell — Sala 3" },
    { "serial": "SN-A39201BX", "note": null }
  ]
}
// Saída: arquivo binário para download
```

### `POST /email`
```json
// Entrada
{
  "to": "funcionario@empresa.com",
  "mode": "attachment" | "text",
  "format": "pdf" | "xlsx" | "txt" | "docx",
  "serials": [
    { "serial": "SN-00X7482K", "note": "Notebook Dell — Sala 3" },
    { "serial": "SN-A39201BX", "note": null }
  ]
}
// Saída
{ "success": true, "message": "E-mail enviado para funcionario@empresa.com" }
```

**Modo text:** seriais listados no corpo do e-mail, sem anexo.  
**Modo attachment:** arquivo gerado e enviado como anexo.

---

## 6. Prompt Claude Haiku

```
Abaixo está o texto extraído de uma imagem de equipamento via OCR.
Identifique o número de série do equipamento.
Retorne APENAS o número de série, sem explicações.
Se não encontrar, retorne: SERIAL_NAO_ENCONTRADO

Texto OCR:
[texto extraído pelo Cloud Vision]
```

---

## 7. Modelo de Dados (Flutter — memória)

```dart
class SerialItem {
  final String serial;
  final String? note;
  final DateTime capturedAt;
}

List<SerialItem> sessionList = [];
```

A lista existe apenas durante a sessão. Ao fechar o app, os dados são perdidos — sem banco de dados ou persistência local.

---

## 8. Estrutura de Pastas

```
projeto - Serial/
├── app/                          ← Projeto Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   │   └── serial_item.dart
│   │   ├── screens/
│   │   │   ├── camera_screen.dart
│   │   │   ├── confirm_screen.dart
│   │   │   └── list_screen.dart
│   │   └── services/
│   │       └── api_service.dart
│   └── pubspec.yaml
│
└── backend/
    ├── index.js
    ├── services/
    │   ├── ocr.js
    │   ├── claude.js
    │   ├── exporter.js
    │   └── mailer.js
    ├── google-key.json           ← nunca versionar
    ├── .env                      ← nunca versionar
    ├── .gitignore
    └── package.json
```

---

## 9. Dependências

### Flutter (`pubspec.yaml`)
| Pacote | Uso |
|---|---|
| `camera` | Acesso à câmera |
| `http` | Chamadas HTTP ao backend |
| `image_picker` | Alternativa: selecionar da galeria |
| `flutter_dotenv` | URL do backend via `.env` local |

### Node.js (`package.json`)
| Pacote | Uso |
|---|---|
| `express` | Servidor HTTP |
| `@google-cloud/vision` | OCR |
| `@anthropic-ai/sdk` | Claude Haiku |
| `resend` | Envio de e-mail |
| `pdfkit` | Geração de PDF |
| `exceljs` | Geração de XLSX |
| `docx` | Geração de DOCX |
| `dotenv` | Variáveis de ambiente |
| `cors` | Requisições cross-origin |

---

## 10. Variáveis de Ambiente (`.env`)

```env
GOOGLE_APPLICATION_CREDENTIALS=./google-key.json
ANTHROPIC_API_KEY=sk-ant-...
RESEND_API_KEY=re_...
EMAIL_FROM=scanner@suaempresa.com
PORT=3000
```

---

## 11. Segurança

- Nenhuma chave de API no código Flutter (APK pode ser descompilado)
- Todas as credenciais no `.env` do backend
- `.env` e `google-key.json` adicionados ao `.gitignore` antes do primeiro commit
- Backend hospedado no Railway com HTTPS por padrão

---

## 12. Design Visual

- **Estilo:** Clean / Moderno
- **Cor primária:** `#4f46e5` (roxo índigo)
- **Cor de erro/descarte:** `#ef4444` (vermelho)
- **Cor de sucesso/e-mail:** `#16a34a` (verde)
- **Tipografia seriais:** monospace
- **Fundo:** `#f5f7fa` (cinza muito claro)
- **Cartões:** branco com sombra suave

---

## 13. Distribuição

- Build: `flutter build apk --release`
- Distribuição por APK direto (WhatsApp / e-mail / link)
- Funcionário habilita "Fontes desconhecidas" nas configurações do Android

---

## 14. Estimativa de Custo Mensal

| Serviço | Custo |
|---|---|
| Google Cloud Vision | Gratuito até 1.000 imagens/mês |
| Claude Haiku | ~US$1–5/mês |
| Resend | Gratuito até 3.000 e-mails/mês |
| Railway (backend) | Gratuito (US$5 crédito/mês) |
| **Total estimado** | **< US$5/mês** |
