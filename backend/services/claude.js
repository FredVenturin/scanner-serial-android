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
