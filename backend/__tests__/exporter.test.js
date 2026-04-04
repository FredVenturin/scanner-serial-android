const { generate } = require('../services/exporter');

const serials = [
  { serial: 'SN-00X7482K', note: 'Notebook Dell' },
  { serial: 'SN-A39201BX', note: null },
];

describe('generate', () => {
  it('gera TXT como Buffer com conteúdo correto', async () => {
    const { buffer, mime, ext } = await generate('txt', serials);
    expect(Buffer.isBuffer(buffer)).toBe(true);
    expect(mime).toBe('text/plain');
    expect(ext).toBe('txt');
    const content = buffer.toString();
    expect(content).toContain('SN-00X7482K');
    expect(content).toContain('Notebook Dell');
    expect(content).toContain('SN-A39201BX');
  });

  it('gera PDF como Buffer não vazio', async () => {
    const { buffer, mime, ext } = await generate('pdf', serials);
    expect(Buffer.isBuffer(buffer)).toBe(true);
    expect(mime).toBe('application/pdf');
    expect(ext).toBe('pdf');
    expect(buffer.length).toBeGreaterThan(0);
  });

  it('gera XLSX como Buffer não vazio', async () => {
    const { buffer, mime, ext } = await generate('xlsx', serials);
    expect(Buffer.isBuffer(buffer)).toBe(true);
    expect(mime).toContain('spreadsheetml');
    expect(ext).toBe('xlsx');
    expect(buffer.length).toBeGreaterThan(0);
  });

  it('gera DOCX como Buffer não vazio', async () => {
    const { buffer, mime, ext } = await generate('docx', serials);
    expect(Buffer.isBuffer(buffer)).toBe(true);
    expect(mime).toContain('wordprocessingml');
    expect(ext).toBe('docx');
    expect(buffer.length).toBeGreaterThan(0);
  });

  it('lança erro para formato inválido', async () => {
    await expect(generate('csv', serials)).rejects.toThrow('Formato inválido: csv');
  });
});
