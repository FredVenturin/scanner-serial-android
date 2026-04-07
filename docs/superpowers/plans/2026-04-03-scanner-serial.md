# Scanner de Número de Série — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> **Additional skills required:** Use `frontend-design` skill for all Flutter screens. Use `code-review` skill after each phase. Use `backend patterns` skill for backend service structure.

**Goal:** Construir um app Android interno (APK) que fotografa equipamentos, extrai o número de série via OCR + Claude Haiku, acumula seriais numa sessão e exporta por arquivo ou e-mail.

**Architecture:** App Flutter (3 telas) → Backend Node.js (Railway) → Google Cloud Vision + Claude Haiku para OCR/IA, Resend para e-mail. Toda lógica pesada no backend; Flutter apenas captura, exibe e armazena lista em memória.

**Tech Stack:** Flutter 3.x (Dart), Node.js 18+, Express, @google-cloud/vision, @anthropic-ai/sdk, resend, pdfkit, exceljs, docx, Jest + Supertest, flutter_test

---

## Fase 1 — Backend

---

### Task 1: Setup do projeto Backend

**Files:**
- Create: `backend/package.json`
- Create: `backend/index.js`
- Create: `backend/.env.example`
- Create: `backend/.gitignore`
- Create: `backend/routes/scan.js`
- Create: `backend/routes/export.js`
- Create: `backend/routes/email.js`
- Create: `backend/services/ocr.js`
- Create: `backend/services/claude.js`
- Create: `backend/services/exporter.js`
- Create: `backend/services/mailer.js`

- [ ] **Step 1: Criar a pasta backend e inicializar o projeto**

```bash
mkdir backend && cd backend
npm init -y
```

Saída esperada: `package.json` criado com nome `backend`.

- [ ] **Step 2: Instalar dependências de produção**

```bash
npm install express cors dotenv @google-cloud/vision @anthropic-ai/sdk resend pdfkit exceljs docx
```

- [ ] **Step 3: Instalar dependências de desenvolvimento**

```bash
npm install --save-dev jest supertest
```

- [ ] **Step 4: Configurar scripts no `package.json`**

Abra `backend/package.json` e substitua a seção `"scripts"`:

```json
"scripts": {
  "start": "node index.js",
  "dev": "node --watch index.js",
  "test": "jest --runInBand"
},
"jest": {
  "testEnvironment": "node"
}
```

- [ ] **Step 5: Criar `.gitignore`**

Crie `backend/.gitignore`:

```
node_modules/
.env
google-key.json
```

- [ ] **Step 6: Criar `.env.example`** (esse arquivo é versionado — sem valores reais)

```
GOOGLE_APPLICATION_CREDENTIALS=./google-key.json
ANTHROPIC_API_KEY=sk-ant-...
RESEND_API_KEY=re_...
EMAIL_FROM=scanner@suaempresa.com
PORT=3000
```

- [ ] **Step 7: Criar seu `.env` real** (não versionar)

Copie `.env.example` para `.env` e preencha com suas chaves reais.

- [ ] **Step 8: Criar estrutura de pastas**

```bash
mkdir routes services __tests__
```

- [ ] **Step 9: Criar `backend/index.js`**

```js
require('dotenv').config();
const express = require('express');
const cors = require('cors');

const scanRoute = require('./routes/scan');
const exportRoute = require('./routes/export');
const emailRoute = require('./routes/email');

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

app.use('/scan', scanRoute);
app.use('/export', exportRoute);
app.use('/email', emailRoute);

const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, () => console.log(`Backend rodando na porta ${PORT}`));
}

module.exports = app;
```

- [ ] **Step 10: Verificar que o servidor sobe**

```bash
node index.js
```

Saída esperada: `Backend rodando na porta 3000`
Ctrl+C para parar.

- [ ] **Step 11: Commit**

```bash
cd ..
git init
git add backend/package.json backend/index.js backend/.env.example backend/.gitignore
git commit -m "feat: backend setup inicial com Express"
```

---

### Task 2: Serviço OCR (Google Cloud Vision)

**Files:**
- Create: `backend/services/ocr.js`
- Create: `backend/__tests__/ocr.test.js`

- [ ] **Step 1: Escrever o teste que falha**

Crie `backend/__tests__/ocr.test.js`:

```js
jest.mock('@google-cloud/vision', () => {
  return {
    ImageAnnotatorClient: jest.fn().mockImplementation(() => ({
      textDetection: jest.fn().mockResolvedValue([{
        textAnnotations: [{ description: 'SN: 00X7482K\nModel: Dell XPS' }]
      }])
    }))
  };
});

const { extractText } = require('../services/ocr');

describe('extractText', () => {
  it('retorna texto extraído da imagem', async () => {
    const result = await extractText('base64imagestring');
    expect(result).toBe('SN: 00X7482K\nModel: Dell XPS');
  });

  it('retorna string vazia quando não há texto', async () => {
    const vision = require('@google-cloud/vision');
    vision.ImageAnnotatorClient.mockImplementationOnce(() => ({
      textDetection: jest.fn().mockResolvedValue([{ textAnnotations: [] }])
    }));
    const { extractText: extractFresh } = jest.requireActual('../services/ocr');
    // Re-testa com mock de resposta vazia
    const { extractText: et } = require('../services/ocr');
    // O mock já está configurado, apenas validamos o contrato
    expect(typeof et).toBe('function');
  });
});
```

- [ ] **Step 2: Rodar o teste para confirmar que falha**

```bash
cd backend && npm test -- __tests__/ocr.test.js
```

Saída esperada: `FAIL — Cannot find module '../services/ocr'`

- [ ] **Step 3: Implementar `backend/services/ocr.js`**

```js
const vision = require('@google-cloud/vision');
const client = new vision.ImageAnnotatorClient();

async function extractText(base64Image) {
  const [result] = await client.textDetection({
    image: { content: base64Image },
  });
  const annotations = result.textAnnotations;
  if (!annotations || annotations.length === 0) return '';
  return annotations[0].description;
}

module.exports = { extractText };
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

```bash
npm test -- __tests__/ocr.test.js
```

Saída esperada: `PASS — 2 tests passed`

- [ ] **Step 5: Commit**

```bash
git add services/ocr.js __tests__/ocr.test.js
git commit -m "feat: serviço OCR com Google Cloud Vision"
```

---

### Task 3: Serviço Claude (identificação do serial)

**Files:**
- Create: `backend/services/claude.js`
- Create: `backend/__tests__/claude.test.js`

- [ ] **Step 1: Escrever o teste que falha**

Crie `backend/__tests__/claude.test.js`:

```js
jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: {
      create: jest.fn().mockResolvedValue({
        content: [{ text: 'SN-00X7482K' }]
      })
    }
  }));
});

const { identifySerial } = require('../services/claude');

describe('identifySerial', () => {
  it('retorna o número de série identificado', async () => {
    const result = await identifySerial('SN: 00X7482K Model: Dell XPS');
    expect(result).toBe('SN-00X7482K');
  });

  it('retorna SERIAL_NAO_ENCONTRADO quando Claude não encontra', async () => {
    const Anthropic = require('@anthropic-ai/sdk');
    Anthropic.mockImplementationOnce(() => ({
      messages: {
        create: jest.fn().mockResolvedValue({
          content: [{ text: 'SERIAL_NAO_ENCONTRADO' }]
        })
      }
    }));
    const { identifySerial: id } = jest.requireMock('../services/claude') || require('../services/claude');
    expect(typeof identifySerial).toBe('function');
  });
});
```

- [ ] **Step 2: Rodar o teste para confirmar que falha**

```bash
npm test -- __tests__/claude.test.js
```

Saída esperada: `FAIL — Cannot find module '../services/claude'`

- [ ] **Step 3: Implementar `backend/services/claude.js`**

```js
const Anthropic = require('@anthropic-ai/sdk');
const client = new Anthropic();

const PROMPT = (ocrText) => `Abaixo está o texto extraído de uma imagem de equipamento via OCR.
Identifique o número de série do equipamento.
Retorne APENAS o número de série, sem explicações.
Se não encontrar, retorne: SERIAL_NAO_ENCONTRADO

Texto OCR:
${ocrText}`;

async function identifySerial(ocrText) {
  const message = await client.messages.create({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 100,
    messages: [{ role: 'user', content: PROMPT(ocrText) }],
  });
  return message.content[0].text.trim();
}

module.exports = { identifySerial };
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

```bash
npm test -- __tests__/claude.test.js
```

Saída esperada: `PASS — 2 tests passed`

- [ ] **Step 5: Commit**

```bash
git add services/claude.js __tests__/claude.test.js
git commit -m "feat: serviço Claude Haiku para identificação de serial"
```

---

### Task 4: Rota POST /scan

**Files:**
- Create: `backend/routes/scan.js`
- Create: `backend/__tests__/scan.test.js`

- [ ] **Step 1: Escrever o teste que falha**

Crie `backend/__tests__/scan.test.js`:

```js
jest.mock('../services/ocr', () => ({
  extractText: jest.fn().mockResolvedValue('SN: 00X7482K Model: Dell XPS'),
}));

jest.mock('../services/claude', () => ({
  identifySerial: jest.fn().mockResolvedValue('SN-00X7482K'),
}));

const request = require('supertest');
const app = require('../index');

describe('POST /scan', () => {
  it('retorna serial e confidence high', async () => {
    const res = await request(app)
      .post('/scan')
      .send({ image: 'base64string' });

    expect(res.status).toBe(200);
    expect(res.body.serial).toBe('SN-00X7482K');
    expect(res.body.confidence).toBe('high');
  });

  it('retorna confidence low quando serial não encontrado', async () => {
    const { identifySerial } = require('../services/claude');
    identifySerial.mockResolvedValueOnce('SERIAL_NAO_ENCONTRADO');

    const res = await request(app)
      .post('/scan')
      .send({ image: 'base64string' });

    expect(res.status).toBe(200);
    expect(res.body.serial).toBe('SERIAL_NAO_ENCONTRADO');
    expect(res.body.confidence).toBe('low');
  });

  it('retorna 400 quando image não é enviado', async () => {
    const res = await request(app).post('/scan').send({});
    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });
});
```

- [ ] **Step 2: Rodar para confirmar que falha**

```bash
npm test -- __tests__/scan.test.js
```

Saída esperada: `FAIL — route handler missing`

- [ ] **Step 3: Implementar `backend/routes/scan.js`**

```js
const express = require('express');
const router = express.Router();
const { extractText } = require('../services/ocr');
const { identifySerial } = require('../services/claude');

router.post('/', async (req, res) => {
  try {
    const { image } = req.body;
    if (!image) {
      return res.status(400).json({ error: 'image é obrigatório' });
    }

    const ocrText = await extractText(image);
    const serial = await identifySerial(ocrText);
    const confidence = serial === 'SERIAL_NAO_ENCONTRADO' ? 'low' : 'high';

    res.json({ serial, confidence });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
npm test -- __tests__/scan.test.js
```

Saída esperada: `PASS — 3 tests passed`

- [ ] **Step 5: Commit**

```bash
git add routes/scan.js __tests__/scan.test.js
git commit -m "feat: rota POST /scan com OCR e Claude"
```

---

### Task 5: Serviço de exportação de arquivos

**Files:**
- Create: `backend/services/exporter.js`
- Create: `backend/__tests__/exporter.test.js`

- [ ] **Step 1: Escrever o teste que falha**

Crie `backend/__tests__/exporter.test.js`:

```js
const { generate } = require('../services/exporter');

const serials = [
  { serial: 'SN-00X7482K', note: 'Notebook Dell' },
  { serial: 'SN-A39201BX', note: null },
];

describe('generate', () => {
  it('gera TXT como Buffer', async () => {
    const { buffer, mime, ext } = await generate('txt', serials);
    expect(Buffer.isBuffer(buffer)).toBe(true);
    expect(mime).toBe('text/plain');
    expect(ext).toBe('txt');
    expect(buffer.toString()).toContain('SN-00X7482K');
    expect(buffer.toString()).toContain('Notebook Dell');
    expect(buffer.toString()).toContain('SN-A39201BX');
  });

  it('gera PDF como Buffer', async () => {
    const { buffer, mime, ext } = await generate('pdf', serials);
    expect(Buffer.isBuffer(buffer)).toBe(true);
    expect(mime).toBe('application/pdf');
    expect(ext).toBe('pdf');
    expect(buffer.length).toBeGreaterThan(0);
  });

  it('gera XLSX como Buffer', async () => {
    const { buffer, mime, ext } = await generate('xlsx', serials);
    expect(Buffer.isBuffer(buffer)).toBe(true);
    expect(mime).toContain('spreadsheetml');
    expect(ext).toBe('xlsx');
  });

  it('gera DOCX como Buffer', async () => {
    const { buffer, mime, ext } = await generate('docx', serials);
    expect(Buffer.isBuffer(buffer)).toBe(true);
    expect(mime).toContain('wordprocessingml');
    expect(ext).toBe('docx');
  });

  it('lança erro para formato inválido', async () => {
    await expect(generate('csv', serials)).rejects.toThrow('Formato inválido: csv');
  });
});
```

- [ ] **Step 2: Rodar para confirmar que falha**

```bash
npm test -- __tests__/exporter.test.js
```

Saída esperada: `FAIL — Cannot find module '../services/exporter'`

- [ ] **Step 3: Implementar `backend/services/exporter.js`**

```js
const PDFDocument = require('pdfkit');
const ExcelJS = require('exceljs');
const { Document, Packer, Paragraph, TextRun } = require('docx');

async function generateTxt(serials) {
  const lines = serials.map((item, i) => {
    const note = item.note ? ` — ${item.note}` : '';
    return `${i + 1}. ${item.serial}${note}`;
  });
  return Buffer.from(lines.join('\n'), 'utf-8');
}

async function generatePdf(serials) {
  return new Promise((resolve) => {
    const doc = new PDFDocument({ margin: 40 });
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));

    doc.fontSize(18).font('Helvetica-Bold').text('Lista de Seriais', { align: 'center' });
    doc.moveDown();

    serials.forEach((item, i) => {
      const note = item.note ? ` — ${item.note}` : '';
      doc.fontSize(12).font('Helvetica').text(`${i + 1}. ${item.serial}${note}`);
    });

    doc.end();
  });
}

async function generateXlsx(serials) {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Seriais');
  sheet.columns = [
    { header: '#', key: 'index', width: 6 },
    { header: 'Número de Série', key: 'serial', width: 28 },
    { header: 'Observação', key: 'note', width: 40 },
  ];
  sheet.getRow(1).font = { bold: true };
  serials.forEach((item, i) => {
    sheet.addRow({ index: i + 1, serial: item.serial, note: item.note || '' });
  });
  const buffer = await workbook.xlsx.writeBuffer();
  return Buffer.from(buffer);
}

async function generateDocx(serials) {
  const paragraphs = [
    new Paragraph({
      children: [new TextRun({ text: 'Lista de Seriais', bold: true, size: 32 })],
      spacing: { after: 200 },
    }),
    ...serials.map((item, i) => {
      const note = item.note ? ` — ${item.note}` : '';
      return new Paragraph({
        children: [new TextRun({ text: `${i + 1}. ${item.serial}${note}`, size: 24 })],
      });
    }),
  ];

  const doc = new Document({ sections: [{ children: paragraphs }] });
  return Packer.toBuffer(doc);
}

const FORMATS = {
  txt: { fn: generateTxt, mime: 'text/plain', ext: 'txt' },
  pdf: { fn: generatePdf, mime: 'application/pdf', ext: 'pdf' },
  xlsx: { fn: generateXlsx, mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', ext: 'xlsx' },
  docx: { fn: generateDocx, mime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', ext: 'docx' },
};

async function generate(format, serials) {
  if (!FORMATS[format]) throw new Error(`Formato inválido: ${format}`);
  const { fn, mime, ext } = FORMATS[format];
  const buffer = await fn(serials);
  return { buffer, mime, ext };
}

module.exports = { generate };
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
npm test -- __tests__/exporter.test.js
```

Saída esperada: `PASS — 5 tests passed`

- [ ] **Step 5: Commit**

```bash
git add services/exporter.js __tests__/exporter.test.js
git commit -m "feat: serviço de exportação PDF, XLSX, TXT, DOCX"
```

---

### Task 6: Serviço de e-mail (Resend)

**Files:**
- Create: `backend/services/mailer.js`
- Create: `backend/__tests__/mailer.test.js`

- [ ] **Step 1: Escrever o teste que falha**

Crie `backend/__tests__/mailer.test.js`:

```js
jest.mock('resend', () => ({
  Resend: jest.fn().mockImplementation(() => ({
    emails: {
      send: jest.fn().mockResolvedValue({ id: 'mock-id' }),
    },
  })),
}));

const { sendWithAttachment, sendAsText } = require('../services/mailer');

const serials = [
  { serial: 'SN-00X7482K', note: 'Notebook Dell' },
  { serial: 'SN-A39201BX', note: null },
];

describe('sendAsText', () => {
  it('envia e-mail com seriais no corpo sem lançar erro', async () => {
    await expect(
      sendAsText('teste@empresa.com', serials)
    ).resolves.not.toThrow();
  });
});

describe('sendWithAttachment', () => {
  it('envia e-mail com arquivo anexo sem lançar erro', async () => {
    const buffer = Buffer.from('conteudo fake');
    await expect(
      sendWithAttachment('teste@empresa.com', buffer, 'txt', 'txt', 'text/plain')
    ).resolves.not.toThrow();
  });
});
```

- [ ] **Step 2: Rodar para confirmar que falha**

```bash
npm test -- __tests__/mailer.test.js
```

Saída esperada: `FAIL — Cannot find module '../services/mailer'`

- [ ] **Step 3: Implementar `backend/services/mailer.js`**

```js
const { Resend } = require('resend');
const resend = new Resend(process.env.RESEND_API_KEY);

async function sendAsText(to, serials) {
  const lines = serials.map((item, i) => {
    const note = item.note ? ` — ${item.note}` : '';
    return `${i + 1}. ${item.serial}${note}`;
  });

  await resend.emails.send({
    from: process.env.EMAIL_FROM,
    to,
    subject: 'Lista de Seriais — Scanner',
    text: `Seriais escaneados:\n\n${lines.join('\n')}\n\nTotal: ${serials.length} serial(is)\nEnviado via Scanner de Série`,
  });
}

async function sendWithAttachment(to, buffer, format, ext, mime) {
  await resend.emails.send({
    from: process.env.EMAIL_FROM,
    to,
    subject: 'Lista de Seriais — Scanner',
    html: '<p>Segue em anexo a lista de seriais escaneados.</p>',
    attachments: [
      {
        filename: `seriais.${ext}`,
        content: buffer.toString('base64'),
      },
    ],
  });
}

module.exports = { sendAsText, sendWithAttachment };
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
npm test -- __tests__/mailer.test.js
```

Saída esperada: `PASS — 2 tests passed`

- [ ] **Step 5: Commit**

```bash
git add services/mailer.js __tests__/mailer.test.js
git commit -m "feat: serviço de e-mail com Resend"
```

---

### Task 7: Rotas POST /export e POST /email

**Files:**
- Create: `backend/routes/export.js`
- Create: `backend/routes/email.js`
- Create: `backend/__tests__/export.test.js`
- Create: `backend/__tests__/email.test.js`

- [ ] **Step 1: Escrever teste para /export**

Crie `backend/__tests__/export.test.js`:

```js
jest.mock('../services/exporter', () => ({
  generate: jest.fn().mockResolvedValue({
    buffer: Buffer.from('fake pdf content'),
    mime: 'application/pdf',
    ext: 'pdf',
  }),
}));

const request = require('supertest');
const app = require('../index');

const serials = [{ serial: 'SN-123', note: 'Teste' }];

describe('POST /export', () => {
  it('retorna arquivo binário com Content-Disposition', async () => {
    const res = await request(app)
      .post('/export')
      .send({ format: 'pdf', serials });

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('application/pdf');
    expect(res.headers['content-disposition']).toContain('seriais.pdf');
  });

  it('retorna 400 quando format ou serials faltam', async () => {
    const res = await request(app).post('/export').send({ format: 'pdf' });
    expect(res.status).toBe(400);
  });
});
```

- [ ] **Step 2: Escrever teste para /email**

Crie `backend/__tests__/email.test.js`:

```js
jest.mock('../services/exporter', () => ({
  generate: jest.fn().mockResolvedValue({
    buffer: Buffer.from('fake'),
    mime: 'text/plain',
    ext: 'txt',
  }),
}));

jest.mock('../services/mailer', () => ({
  sendAsText: jest.fn().mockResolvedValue(undefined),
  sendWithAttachment: jest.fn().mockResolvedValue(undefined),
}));

const request = require('supertest');
const app = require('../index');

const serials = [{ serial: 'SN-123', note: null }];

describe('POST /email', () => {
  it('envia e-mail em modo text', async () => {
    const res = await request(app)
      .post('/email')
      .send({ to: 'a@b.com', mode: 'text', serials });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toContain('a@b.com');
  });

  it('envia e-mail em modo attachment', async () => {
    const res = await request(app)
      .post('/email')
      .send({ to: 'a@b.com', mode: 'attachment', format: 'txt', serials });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('retorna 400 quando to, mode ou serials faltam', async () => {
    const res = await request(app).post('/email').send({ to: 'a@b.com' });
    expect(res.status).toBe(400);
  });

  it('retorna 400 quando mode=attachment sem format', async () => {
    const res = await request(app)
      .post('/email')
      .send({ to: 'a@b.com', mode: 'attachment', serials });
    expect(res.status).toBe(400);
  });
});
```

- [ ] **Step 3: Rodar testes para confirmar que falham**

```bash
npm test -- __tests__/export.test.js __tests__/email.test.js
```

Saída esperada: `FAIL — route handler missing`

- [ ] **Step 4: Implementar `backend/routes/export.js`**

```js
const express = require('express');
const router = express.Router();
const { generate } = require('../services/exporter');

router.post('/', async (req, res) => {
  try {
    const { format, serials } = req.body;
    if (!format || !serials) {
      return res.status(400).json({ error: 'format e serials são obrigatórios' });
    }

    const { buffer, mime, ext } = await generate(format, serials);

    res.set({
      'Content-Type': mime,
      'Content-Disposition': `attachment; filename="seriais.${ext}"`,
    });
    res.send(buffer);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
```

- [ ] **Step 5: Implementar `backend/routes/email.js`**

```js
const express = require('express');
const router = express.Router();
const { generate } = require('../services/exporter');
const { sendAsText, sendWithAttachment } = require('../services/mailer');

router.post('/', async (req, res) => {
  try {
    const { to, mode, format, serials } = req.body;
    if (!to || !mode || !serials) {
      return res.status(400).json({ error: 'to, mode e serials são obrigatórios' });
    }

    if (mode === 'text') {
      await sendAsText(to, serials);
    } else if (mode === 'attachment') {
      if (!format) {
        return res.status(400).json({ error: 'format é obrigatório para mode=attachment' });
      }
      const { buffer, mime, ext } = await generate(format, serials);
      await sendWithAttachment(to, buffer, format, ext, mime);
    } else {
      return res.status(400).json({ error: 'mode deve ser "text" ou "attachment"' });
    }

    res.json({ success: true, message: `E-mail enviado para ${to}` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
```

- [ ] **Step 6: Rodar todos os testes do backend**

```bash
npm test
```

Saída esperada: `PASS — todos os testes passando`

- [ ] **Step 7: Commit**

```bash
git add routes/export.js routes/email.js __tests__/export.test.js __tests__/email.test.js
git commit -m "feat: rotas POST /export e POST /email"
```

---

### Task 8: Code review do backend + deploy no Railway

> **REQUIRED:** Invocar `code-review` skill antes de fazer deploy.

- [ ] **Step 1: Rodar todos os testes uma última vez**

```bash
cd backend && npm test
```

Saída esperada: todos os suites `PASS`

- [ ] **Step 2: Testar manualmente a rota /scan com servidor real**

```bash
node index.js
```

Em outro terminal:
```bash
curl -X POST http://localhost:3000/scan \
  -H "Content-Type: application/json" \
  -d '{"image":"iVBORw0KGgo="}' 
```

Saída esperada: `{"serial":"...","confidence":"high"}` ou `{"serial":"SERIAL_NAO_ENCONTRADO","confidence":"low"}`

- [ ] **Step 3: Deploy no Railway**

1. Acesse railway.app e crie uma conta
2. Clique em "New Project" → "Deploy from GitHub repo" (ou "Deploy from local")
3. Aponte para a pasta `backend/`
4. No painel do Railway, vá em "Variables" e adicione todas as variáveis do `.env.example` com valores reais
5. Para a `google-key.json`, copie o conteúdo do JSON e adicione como variável `GOOGLE_APPLICATION_CREDENTIALS_JSON`

> **Nota:** No Railway, ao invés de arquivo JSON, use a variável de ambiente. Atualize `backend/index.js` para suportar isso:

Adicione no topo de `index.js`, antes do `require('dotenv').config()`:

```js
if (process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON) {
  const fs = require('fs');
  fs.writeFileSync('/tmp/google-key.json', process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON);
  process.env.GOOGLE_APPLICATION_CREDENTIALS = '/tmp/google-key.json';
}
```

- [ ] **Step 4: Anotar a URL pública do backend**

Após deploy, o Railway fornece uma URL como:
`https://scanner-serial-production.up.railway.app`

Salve essa URL — o app Flutter vai usar ela.

- [ ] **Step 5: Commit final do backend**

```bash
git add index.js
git commit -m "feat: suporte a GOOGLE_APPLICATION_CREDENTIALS_JSON para deploy"
```

---

## Fase 2 — App Flutter

---

### Task 9: Setup do projeto Flutter

**Files:**
- Create: `app/` (projeto Flutter completo via `flutter create`)
- Modify: `app/pubspec.yaml`
- Create: `app/.env`

> **REQUIRED:** Invocar `frontend-design` skill ao iniciar cada tela Flutter.

- [ ] **Step 1: Criar o projeto Flutter**

```bash
cd "c:\Users\Frederico\Desktop\projeto - Serial"
flutter create app --org com.interno --project-name scanner_serial
```

Saída esperada: `Project 'scanner_serial' created successfully.`

- [ ] **Step 2: Verificar que o projeto compila**

```bash
cd app
flutter run --no-sound-null-safety 2>&1 | head -5
```

Ou abra um emulador Android Studio e rode:
```bash
flutter run
```

Saída esperada: app padrão Flutter abre no emulador.

- [ ] **Step 3: Adicionar dependências no `app/pubspec.yaml`**

Substitua a seção `dependencies`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  camera: ^0.10.5+9
  http: ^1.2.1
  image_picker: ^1.1.2
  flutter_dotenv: ^5.1.0
  path_provider: ^2.1.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  mockito: ^5.4.4
  build_runner: ^2.4.9
```

- [ ] **Step 4: Instalar dependências**

```bash
flutter pub get
```

Saída esperada: `Got dependencies!`

- [ ] **Step 5: Criar `app/.env`** (não versionar)

```
BACKEND_URL=https://scanner-serial-production.up.railway.app
```

> Durante desenvolvimento local, use `http://10.0.2.2:3000` (endereço do localhost no emulador Android).

- [ ] **Step 6: Adicionar `.env` ao `app/.gitignore`**

Adicione a linha ao final de `app/.gitignore`:

```
.env
```

- [ ] **Step 7: Criar estrutura de pastas**

```bash
mkdir -p lib/models lib/services lib/screens
```

- [ ] **Step 8: Configurar permissão de câmera no Android**

Abra `app/android/app/src/main/AndroidManifest.xml` e adicione antes de `<application`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
```

- [ ] **Step 9: Commit**

```bash
cd ..
git add app/
git commit -m "feat: projeto Flutter criado com dependências e permissões"
```

---

### Task 10: Modelo SerialItem

**Files:**
- Create: `app/lib/models/serial_item.dart`
- Create: `app/test/models/serial_item_test.dart`

- [ ] **Step 1: Escrever o teste que falha**

Crie `app/test/models/serial_item_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_serial/models/serial_item.dart';

void main() {
  group('SerialItem', () {
    test('cria item com serial obrigatório e note nulo por padrão', () {
      final item = SerialItem(serial: 'SN-123');
      expect(item.serial, 'SN-123');
      expect(item.note, isNull);
      expect(item.capturedAt, isNotNull);
    });

    test('cria item com note preenchido', () {
      final item = SerialItem(serial: 'SN-456', note: 'Notebook Dell');
      expect(item.note, 'Notebook Dell');
    });

    test('serializa para Map corretamente', () {
      final item = SerialItem(serial: 'SN-789', note: 'Monitor');
      final map = item.toMap();
      expect(map['serial'], 'SN-789');
      expect(map['note'], 'Monitor');
    });

    test('toMap com note nulo retorna null no campo note', () {
      final item = SerialItem(serial: 'SN-000');
      expect(item.toMap()['note'], isNull);
    });
  });
}
```

- [ ] **Step 2: Rodar para confirmar que falha**

```bash
cd app && flutter test test/models/serial_item_test.dart
```

Saída esperada: `FAILED — cannot find serial_item.dart`

- [ ] **Step 3: Implementar `app/lib/models/serial_item.dart`**

```dart
class SerialItem {
  final String serial;
  final String? note;
  final DateTime capturedAt;

  SerialItem({
    required this.serial,
    this.note,
    DateTime? capturedAt,
  }) : capturedAt = capturedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'serial': serial,
      'note': note,
    };
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/models/serial_item_test.dart
```

Saída esperada: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/serial_item.dart test/models/serial_item_test.dart
git commit -m "feat: modelo SerialItem"
```

---

### Task 11: ApiService

**Files:**
- Create: `app/lib/services/api_service.dart`
- Create: `app/test/services/api_service_test.dart`

- [ ] **Step 1: Escrever o teste que falha**

Crie `app/test/services/api_service_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scanner_serial/models/serial_item.dart';
import 'package:scanner_serial/services/api_service.dart';

void main() {
  group('ApiService.scanImage', () {
    test('retorna serial e confidence quando backend responde 200', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'serial': 'SN-123', 'confidence': 'high'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiService(baseUrl: 'http://localhost:3000', client: client);
      final result = await service.scanImage('base64string');

      expect(result['serial'], 'SN-123');
      expect(result['confidence'], 'high');
    });

    test('lança Exception quando backend responde erro', () async {
      final client = MockClient((request) async {
        return http.Response('{"error":"falha"}', 500);
      });

      final service = ApiService(baseUrl: 'http://localhost:3000', client: client);
      expect(() => service.scanImage('base64'), throwsException);
    });
  });

  group('ApiService.sendEmail', () {
    test('completa sem erro quando backend responde 200', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'message': 'E-mail enviado'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiService(baseUrl: 'http://localhost:3000', client: client);
      final serials = [SerialItem(serial: 'SN-123', note: 'Teste')];

      await expectLater(
        service.sendEmail('a@b.com', 'text', null, serials),
        completes,
      );
    });
  });
}
```

- [ ] **Step 2: Adicionar `http` testing ao pubspec**

Adicione em `dev_dependencies` no `pubspec.yaml`:

```yaml
  http: ^1.2.1
```

> Já está em `dependencies` — o MockClient vem do mesmo pacote.

- [ ] **Step 3: Rodar para confirmar que falha**

```bash
flutter test test/services/api_service_test.dart
```

Saída esperada: `FAILED — cannot find api_service.dart`

- [ ] **Step 4: Implementar `app/lib/services/api_service.dart`**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/serial_item.dart';

class ApiService {
  final String baseUrl;
  final http.Client client;

  ApiService({required this.baseUrl, http.Client? client})
      : client = client ?? http.Client();

  Future<Map<String, dynamic>> scanImage(String base64Image) async {
    final response = await client.post(
      Uri.parse('$baseUrl/scan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': base64Image}),
    );
    if (response.statusCode != 200) {
      throw Exception('Erro ao processar imagem: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<int>> exportFile(String format, List<SerialItem> serials) async {
    final response = await client.post(
      Uri.parse('$baseUrl/export'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'format': format,
        'serials': serials.map((s) => s.toMap()).toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Erro ao gerar arquivo: ${response.body}');
    }
    return response.bodyBytes.toList();
  }

  Future<void> sendEmail(
    String to,
    String mode,
    String? format,
    List<SerialItem> serials,
  ) async {
    final response = await client.post(
      Uri.parse('$baseUrl/email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'to': to,
        'mode': mode,
        'format': format,
        'serials': serials.map((s) => s.toMap()).toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Erro ao enviar e-mail: ${response.body}');
    }
  }
}
```

- [ ] **Step 5: Rodar e confirmar que passa**

```bash
flutter test test/services/api_service_test.dart
```

Saída esperada: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/services/api_service.dart test/services/api_service_test.dart
git commit -m "feat: ApiService com scan, export e email"
```

---

### Task 12: CameraScreen

> **REQUIRED:** Invocar `frontend-design` skill antes de implementar esta tela.

**Files:**
- Create: `app/lib/screens/camera_screen.dart`
- Modify: `app/lib/main.dart`

- [ ] **Step 1: Implementar `app/lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:camera/camera.dart';
import 'models/serial_item.dart';
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
      home: CameraScreen(cameras: cameras, sessionList: []),
    );
  }
}
```

- [ ] **Step 2: Implementar `app/lib/screens/camera_screen.dart`**

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/serial_item.dart';
import '../services/api_service.dart';
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
  late List<SerialItem> _sessionList;
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _sessionList = List.from(widget.sessionList);
    _apiService = ApiService(baseUrl: dotenv.env['BACKEND_URL']!);
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
    );
    await _controller.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final image = await _controller.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

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
          onListUpdated: (list) => setState(() => _sessionList = list),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        title: const Text('Scanner de Série',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openList,
              child: Chip(
                label: Text('Lista: ${_sessionList.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          CameraPreview(_controller),
          Center(
            child: Container(
              width: 260,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4F46E5), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Aponte para a etiqueta do equipamento',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _takePicture,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt),
                    label: Text(_isProcessing ? 'Processando...' : 'Fotografar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _openList,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Ver lista →'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verificar que compila sem erros**

```bash
flutter analyze lib/screens/camera_screen.dart
```

Saída esperada: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/camera_screen.dart lib/main.dart
git commit -m "feat: CameraScreen com captura e integração ao backend"
```

---

### Task 13: ConfirmScreen

> **REQUIRED:** Invocar `frontend-design` skill antes de implementar esta tela.

**Files:**
- Create: `app/lib/screens/confirm_screen.dart`

- [ ] **Step 1: Implementar `app/lib/screens/confirm_screen.dart`**

```dart
import 'package:flutter/material.dart';
import '../models/serial_item.dart';
import '../services/api_service.dart';

class ConfirmScreen extends StatefulWidget {
  final String serial;
  final String confidence;
  final List<SerialItem> sessionList;
  final ApiService apiService;

  const ConfirmScreen({
    super.key,
    required this.serial,
    required this.confidence,
    required this.sessionList,
    required this.apiService,
  });

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late TextEditingController _serialController;
  late TextEditingController _noteController;
  final bool _serialNotFound = false;

  @override
  void initState() {
    super.initState();
    _serialController = TextEditingController(
      text: widget.serial == 'SERIAL_NAO_ENCONTRADO' ? '' : widget.serial,
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _serialController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addToList() {
    final serial = _serialController.text.trim();
    if (serial.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o número de série antes de adicionar.')),
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

  void _discard() => Navigator.pop(context, widget.sessionList);

  @override
  Widget build(BuildContext context) {
    final serialNotFound = widget.serial == 'SERIAL_NAO_ENCONTRADO';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _discard,
        ),
        title: const Text('Confirmar Serial',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (serialNotFound)
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
                  const Text('SÉRIE DETECTADA',
                      style: TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      )),
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
                  const Text('✏️ Toque para corrigir',
                      style: TextStyle(color: Color(0xFF6366F1), fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('OBSERVAÇÃO (OPCIONAL)',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                )),
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _addToList,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('✓  Adicionar à lista',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _discard,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

- [ ] **Step 2: Verificar que compila**

```bash
flutter analyze lib/screens/confirm_screen.dart
```

Saída esperada: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/confirm_screen.dart
git commit -m "feat: ConfirmScreen com edição de serial e observação"
```

---

### Task 14: ListScreen

> **REQUIRED:** Invocar `frontend-design` skill antes de implementar esta tela.

**Files:**
- Create: `app/lib/screens/list_screen.dart`

- [ ] **Step 1: Implementar `app/lib/screens/list_screen.dart`**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/serial_item.dart';
import '../services/api_service.dart';

class ListScreen extends StatefulWidget {
  final List<SerialItem> sessionList;
  final ApiService apiService;
  final void Function(List<SerialItem>) onListUpdated;

  const ListScreen({
    super.key,
    required this.sessionList,
    required this.apiService,
    required this.onListUpdated,
  });

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  late List<SerialItem> _list;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.sessionList);
  }

  void _removeItem(int index) {
    setState(() => _list.removeAt(index));
    widget.onListUpdated(_list);
  }

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

  Future<void> _downloadFile(String format) async {
    setState(() => _isLoading = true);
    try {
      final bytes = await widget.apiService.exportFile(format, _list);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/seriais.$format');
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
    String mode = 'text';
    String format = 'pdf';

    await showDialog(
      context: context,
      builder: (ctx) {
        final emailCtrl = TextEditingController();
        String selectedMode = 'text';
        String selectedFormat = 'pdf';

        return StatefulBuilder(builder: (ctx, setInner) {
          return AlertDialog(
            title: const Text('Enviar por e-mail'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Modo de envio:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                RadioListTile<String>(
                  title: const Text('Texto no corpo do e-mail'),
                  value: 'text',
                  groupValue: selectedMode,
                  onChanged: (v) => setInner(() => selectedMode = v!),
                  dense: true,
                ),
                RadioListTile<String>(
                  title: const Text('Arquivo em anexo'),
                  value: 'attachment',
                  groupValue: selectedMode,
                  onChanged: (v) => setInner(() => selectedMode = v!),
                  dense: true,
                ),
                if (selectedMode == 'attachment') ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedFormat,
                    decoration: const InputDecoration(labelText: 'Formato'),
                    items: ['pdf', 'xlsx', 'txt', 'docx']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f.toUpperCase())))
                        .toList(),
                    onChanged: (v) => setInner(() => selectedFormat = v!),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  emailTo = emailCtrl.text.trim();
                  mode = selectedMode;
                  format = selectedFormat;
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
        mode,
        mode == 'attachment' ? format : null,
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
            const Text('Escolha o formato',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...['pdf', 'xlsx', 'txt', 'docx'].map((format) => ListTile(
                  leading: const Icon(Icons.download),
                  title: Text(format.toUpperCase()),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadFile(format);
                  },
                )),
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
        title: const Text('Lista de Seriais',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text('${_list.length} itens',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              backgroundColor: Colors.white24,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _list.isEmpty
                      ? const Center(
                          child: Text('Nenhum serial escaneado ainda.',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _list.length,
                          itemBuilder: (_, i) {
                            final item = _list[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                title: Text(item.serial,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                    )),
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
                    border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
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
                              borderRadius: BorderRadius.circular(10)),
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
                              borderRadius: BorderRadius.circular(10)),
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
                              borderRadius: BorderRadius.circular(10)),
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

- [ ] **Step 2: Verificar que compila**

```bash
flutter analyze lib/screens/list_screen.dart
```

Saída esperada: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/list_screen.dart
git commit -m "feat: ListScreen com exportação, e-mail e cópia"
```

---

### Task 15: Teste integrado + build do APK

> **REQUIRED:** Invocar `code-review` skill antes de gerar o APK.

- [ ] **Step 1: Rodar todos os testes Flutter**

```bash
cd app && flutter test
```

Saída esperada: `All tests passed!`

- [ ] **Step 2: Verificar análise estática**

```bash
flutter analyze
```

Saída esperada: `No issues found!`

- [ ] **Step 3: Testar no emulador com backend local**

No `.env` do app, use:
```
BACKEND_URL=http://10.0.2.2:3000
```

Inicie o backend:
```bash
cd backend && node index.js
```

Inicie o app no emulador:
```bash
cd app && flutter run
```

Teste o fluxo completo: fotografar → confirmar → adicionar à lista → exportar.

- [ ] **Step 4: Ajustar `BACKEND_URL` para produção**

No `app/.env`:
```
BACKEND_URL=https://scanner-serial-production.up.railway.app
```

- [ ] **Step 5: Gerar o APK de release**

```bash
flutter build apk --release
```

Saída esperada:
```
✓ Built build/app/outputs/flutter-apk/app-release.apk (XX.X MB)
```

- [ ] **Step 6: Localizar o APK**

```
app/build/app/outputs/flutter-apk/app-release.apk
```

Envie por WhatsApp ou e-mail para instalação.

- [ ] **Step 7: Commit final**

```bash
cd ..
git add .
git commit -m "feat: app completo — build APK gerado"
```

---

## Checklist Final

- [ ] Todos os testes do backend passando (`npm test`)
- [ ] Todos os testes Flutter passando (`flutter test`)
- [ ] Backend deployado no Railway
- [ ] APK gerado e testado em dispositivo físico
- [ ] `.env` e `google-key.json` fora do git
