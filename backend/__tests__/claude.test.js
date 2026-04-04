const mockCreate = jest.fn().mockResolvedValue({
  content: [{ text: 'SN-00X7482K' }]
});

jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockCreate }
  }));
});

const { identifySerial } = require('../services/claude');

describe('identifySerial', () => {
  beforeEach(() => mockCreate.mockClear());

  it('retorna o número de série identificado', async () => {
    const result = await identifySerial('SN: 00X7482K Model: Dell XPS');
    expect(result).toBe('SN-00X7482K');
  });

  it('retorna SERIAL_NAO_ENCONTRADO quando Claude não encontra', async () => {
    mockCreate.mockResolvedValueOnce({
      content: [{ text: 'SERIAL_NAO_ENCONTRADO' }]
    });
    const result = await identifySerial('texto sem serial');
    expect(result).toBe('SERIAL_NAO_ENCONTRADO');
  });

  it('inclui o texto OCR no prompt enviado ao Claude', async () => {
    await identifySerial('MODELO: XYZ SN: 9876');
    const callArgs = mockCreate.mock.calls[0][0];
    expect(callArgs.messages[0].content).toContain('MODELO: XYZ SN: 9876');
  });
});
