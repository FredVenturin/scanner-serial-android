# Sistema de Lotes — Scanner de Série v1.2

**Data:** 2026-04-07  
**Contexto:** Segunda iteração do app após primeiro teste em campo. Substituição do sistema de lista única por sistema de lotes múltiplos.

---

## Objetivo

Permitir que funcionários organizem séries escaneadas em lotes nomeados (ex: "Sala 3", "Andar 2"), com gerenciamento completo e verificação de duplicatas entre todos os lotes.

---

## 1. Modelo de Dados

### Batch (novo)
```dart
class Batch {
  final String id;       // UUID gerado na criação
  final String name;     // Nome do lote (max 30 chars)
  final DateTime createdAt;
  final List<SerialItem> items;
}
```

### SerialItem (sem alterações)
```dart
class SerialItem {
  final String serial;
  final String? note;
  final DateTime capturedAt;
}
```

### StorageService (reescrito)
- Salva/carrega lista de `Batch` em SharedPreferences sob a chave `batches` (JSON)
- Salva o ID do último lote usado sob a chave `last_batch_id`
- Máximo de 5 lotes simultâneos
- Métodos: `saveBatches`, `loadBatches`, `saveLastBatchId`, `loadLastBatchId`, `clearAll`

---

## 2. Navegação

```
CameraScreen  
  ↓ botão "Ver lotes"  
BatchListScreen — lista de lotes  
  ↓ toca num lote  
BatchDetailScreen — séries do lote  

CameraScreen → Fotografar  
  ↓  
ConfirmScreen — serial + seletor de lote  
  ↓ confirma  
CameraScreen  
```

**Telas removidas:** `ListScreen` (substituída por `BatchListScreen` + `BatchDetailScreen`)

---

## 3. Telas

### 3.1 CameraScreen (modificada)

- Botão "Ver lista →" substituído por "Ver lotes →"
- Chip superior direito alterado de `Lista: X` para `Lotes: N | Séries: T` (N = número de lotes, T = total de séries em todos os lotes)
- Navega para `BatchListScreen`

### 3.2 BatchListScreen (nova)

**AppBar:** "Meus Lotes" + botão "+" para criar novo lote  
**Body:** Lista de cards, um por lote  
**Card de lote:**
- Nome do lote
- Contagem: `X séries`
- Ícone de lápis (editar nome)
- Ícone de lixeira (deletar lote)
- Toque no card abre `BatchDetailScreen`

**Regras:**
- Botão "+" desabilitado com tooltip "Limite de 5 lotes atingido" quando há 5 lotes
- Se não há lotes: mensagem central "Nenhum lote criado. Toque em + para começar."

**Criar lote:** Dialog com campo de nome (obrigatório, max 30 chars) + botões Cancelar / Criar  
**Editar lote:** Dialog com nome pré-preenchido + botões Cancelar / Salvar  
**Deletar lote:** AlertDialog de confirmação "Tem certeza? O lote '[nome]' e todas as suas séries serão apagados." + botões Cancelar / Apagar

### 3.3 BatchDetailScreen (nova)

**AppBar:** Nome do lote + contagem `(X séries)`  
**Body:** Lista de séries do lote (igual à ListScreen atual)
- Cada item: serial (monospace, bold) + observação + ícone de deletar
- Série pode ser deletada individualmente

**Rodapé:** Botões "Baixar arquivo" e "Copiar todos" (mesma lógica atual)  
**Comportamento de download:** Usa nome do lote como nome do arquivo exportado

### 3.4 ConfirmScreen (modificada)

Adiciona abaixo do campo de serial e observação:

**Com lotes existentes:**
- Label "Lote de destino"
- Dropdown mostrando todos os lotes no formato `Nome do lote (X séries)`
- Último lote usado pré-selecionado (visível, pode ser trocado)

**Sem lotes:**
- Mensagem "Você não tem lotes criados ainda"
- Botão "Criar lote" abre dialog de criação sem sair da tela
- Após criar, o lote recém-criado é selecionado automaticamente

**Botão "Adicionar à lista"** só habilitado quando um lote está selecionado

---

## 4. Regras de Negócio

### Duplicata
- Verificação em **todos os lotes** antes de inserir
- Se encontrada: AlertDialog "O serial '[X]' já existe no lote '[nome]'. Deseja adicionar mesmo assim?" + botões Não / Sim, adicionar
- Comparação case-insensitive com trim

### Limite de lotes
- Máximo 5 lotes simultâneos
- Sem limite de séries por lote

### Último lote usado
- Salvo por ID após cada adição
- Pré-selecionado automaticamente no dropdown da ConfirmScreen
- Se o último lote foi deletado, nenhum fica pré-selecionado

---

## 5. Arquitetura de Arquivos

| Arquivo | Ação | Responsabilidade |
|---|---|---|
| `app/lib/models/batch.dart` | Criar | Modelo Batch com serialização |
| `app/lib/services/storage_service.dart` | Reescrever | Gerenciar lista de Batch |
| `app/lib/screens/batch_list_screen.dart` | Criar | Tela de lista de lotes |
| `app/lib/screens/batch_detail_screen.dart` | Criar | Tela de séries de um lote |
| `app/lib/screens/confirm_screen.dart` | Modificar | Adicionar seletor de lote |
| `app/lib/screens/camera_screen.dart` | Modificar | Atualizar chip e navegação |
| `app/lib/screens/list_screen.dart` | Deletar | Substituída pelas duas novas |

---

## 6. O que NÃO muda

- Backend (Node.js) — nenhuma alteração necessária
- Exportação de arquivo (PDF, XLSX, TXT, DOCX) — mesma lógica
- Câmera, flash, compressão de imagem
- SerialItem model
