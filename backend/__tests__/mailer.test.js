const mockSend = jest.fn().mockResolvedValue({ id: 'mock-id' });

jest.mock('resend', () => ({
  Resend: jest.fn().mockImplementation(() => ({
    emails: { send: mockSend },
  })),
}));

const { sendAsText, sendWithAttachment } = require('../services/mailer');

const serials = [
  { serial: 'SN-00X7482K', note: 'Notebook Dell' },
  { serial: 'SN-A39201BX', note: null },
];

describe('sendAsText', () => {
  beforeEach(() => mockSend.mockClear());

  it('chama resend.emails.send sem lançar erro', async () => {
    await expect(
      sendAsText('teste@empresa.com', serials)
    ).resolves.not.toThrow();
    expect(mockSend).toHaveBeenCalledTimes(1);
  });

  it('inclui os seriais no corpo do e-mail', async () => {
    await sendAsText('teste@empresa.com', serials);
    const callArgs = mockSend.mock.calls[0][0];
    expect(callArgs.text).toContain('SN-00X7482K');
    expect(callArgs.text).toContain('Notebook Dell');
    expect(callArgs.text).toContain('SN-A39201BX');
  });

  it('envia para o destinatário correto', async () => {
    await sendAsText('destino@empresa.com', serials);
    const callArgs = mockSend.mock.calls[0][0];
    expect(callArgs.to).toBe('destino@empresa.com');
  });
});

describe('sendWithAttachment', () => {
  beforeEach(() => mockSend.mockClear());

  it('chama resend.emails.send com attachment sem lançar erro', async () => {
    const buffer = Buffer.from('conteudo fake');
    await expect(
      sendWithAttachment('teste@empresa.com', buffer, 'txt', 'txt', 'text/plain')
    ).resolves.not.toThrow();
    expect(mockSend).toHaveBeenCalledTimes(1);
  });

  it('inclui o arquivo como attachment no e-mail', async () => {
    const buffer = Buffer.from('conteudo fake');
    await sendWithAttachment('teste@empresa.com', buffer, 'pdf', 'pdf', 'application/pdf');
    const callArgs = mockSend.mock.calls[0][0];
    expect(callArgs.attachments).toBeDefined();
    expect(callArgs.attachments.length).toBeGreaterThan(0);
    expect(callArgs.attachments[0].filename).toContain('pdf');
  });
});
