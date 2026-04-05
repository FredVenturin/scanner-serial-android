# Scanner de Série v1.1 — Correções e Melhorias

**Data:** 2026-04-05
**Contexto:** Feedback do primeiro teste com funcionários em campo.

---

## 1. Velocidade — Otimização de Imagem

**Problema:** Após clicar em "Fotografar", o app demora muito para retornar o serial. A imagem em alta resolução (~5-10MB em base64) trafega inteira até o backend.

**Solução:**
- Reduzir resolução da câmera de `ResolutionPreset.high` para `ResolutionPreset.medium` em `camera_screen.dart`
- Comprimir a imagem JPEG para ~70% de qualidade usando o pacote `image` do Flutter antes de converter para base64
- Resultado esperado: imagem de ~5MB → ~500KB, redução de ~80% no tempo de upload

**Arquivos afetados:**
- `app/lib/screens/camera_screen.dart` — resolução + compressão
- `app/pubspec.yaml` — adicionar dependência `image`

---

## 2. Flash — Botão Manual Liga/Desliga

**Problema:** Não há controle de flash na câmera.

**Solução:**
- Adicionar ícone de flash na AppBar da CameraScreen
- Toggle entre `FlashMode.off` e `FlashMode.torch`
- Ícone muda visualmente: `Icons.flash_off` / `Icons.flash_on`
- Estado padrão: desligado

**Arquivos afetados:**
- `app/lib/screens/camera_screen.dart` — estado do flash + botão na AppBar

---

## 3. Copiar Seriais — Somente Números

**Problema:** A função "Copiar todos" inclui numeração e observações. O funcionário quer apenas os números de série limpos.

**Solução:**
- Alterar `_copyAll()` em `list_screen.dart` para gerar apenas seriais, um por linha:
  ```
  ABC123
  XYZ789
  ```
- Sem numeração, sem observações, sem formatação extra

**Arquivos afetados:**
- `app/lib/screens/list_screen.dart` — método `_copyAll()`

---

## 4. Salvar Lista com Nome + Persistência Local

**Problema:** Se o app for fechado acidentalmente, a lista é perdida. Também não há como nomear a sessão.

**Solução:**

### 4a. Nome da sessão
- Campo editável no topo da ListScreen para definir o nome (ex: "Sala 3 - 05/04")
- Nome padrão: "Lista {data de hoje}"
- Nome usado como título do arquivo exportado (ex: `Sala 3 - 05-04.pdf`)
- Nome usado no assunto do email: "Lista de Seriais — Sala 3 - 05/04"

### 4b. Persistência local
- Usar `SharedPreferences` para salvar automaticamente:
  - Nome da sessão
  - Lista de seriais (JSON serializado)
- Salvar a cada alteração (adicionar, remover item, mudar nome)
- Ao abrir o app: carregar lista anterior se existir
- Botão "Nova lista" na ListScreen para limpar tudo e começar do zero
- Ao clicar "Nova lista": confirmar com dialog "Tem certeza? A lista atual será apagada."

**Arquivos afetados:**
- `app/lib/screens/list_screen.dart` — campo de nome, botão "Nova lista"
- `app/lib/screens/camera_screen.dart` — carregar lista do SharedPreferences no initState
- `app/lib/models/serial_item.dart` — adicionar `fromMap()` para deserialização
- `app/pubspec.yaml` — adicionar dependência `shared_preferences`

---

## 5. Alerta de Série Duplicada

**Problema:** Não há verificação se um serial já foi adicionado à lista.

**Solução:**
- Na ConfirmScreen, ao clicar "Adicionar à lista", verificar se o serial já existe na `sessionList`
- Se duplicado: exibir AlertDialog:
  - Título: "Série duplicada"
  - Mensagem: "O serial {SERIAL} já está na lista. Deseja adicionar mesmo assim?"
  - Botões: "Não" (cancela) / "Sim, adicionar" (adiciona)
- Comparação case-insensitive e trim

**Arquivos afetados:**
- `app/lib/screens/confirm_screen.dart` — método `_addToList()`

---

## 6. Email Funcionando

**Problema:** O email diz que foi enviado mas não chega. Causa: `EMAIL_FROM` usa `onboarding@resend.dev` (remetente de teste do Resend), que só entrega para o email da própria conta.

**Solução:**
- Verificar domínio da empresa no Resend (configuração DNS: registros MX e TXT)
- Criar remetente no formato `scanner@empresa.com.br`
- Atualizar variável `EMAIL_FROM` no Railway e no `.env` local
- Testar envio para destinatários externos

**Arquivos afetados:**
- Railway Variables — `EMAIL_FROM`
- `backend/.env` — `EMAIL_FROM`
- Configuração DNS do domínio (fora do código)

---

## Dependências Novas (Flutter)

| Pacote | Versão | Uso |
|---|---|---|
| `image` | ^4.x | Compressão JPEG |
| `shared_preferences` | ^2.x | Persistência local da lista |

## Ordem de Implementação Sugerida

1. Velocidade (impacto imediato na experiência)
2. Flash (rápido de implementar)
3. Copiar seriais (1 linha de mudança)
4. Alerta de duplicada (mudança localizada)
5. Salvar lista com nome + persistência (mais complexo)
6. Email (depende de configuração externa do domínio)
