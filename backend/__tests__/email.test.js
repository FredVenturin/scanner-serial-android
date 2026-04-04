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
  it('envia e-mail em modo text e retorna success', async () => {
    const res = await request(app)
      .post('/email')
      .send({ to: 'a@b.com', mode: 'text', serials });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toContain('a@b.com');
  });

  it('envia e-mail em modo attachment e retorna success', async () => {
    const res = await request(app)
      .post('/email')
      .send({ to: 'a@b.com', mode: 'attachment', format: 'txt', serials });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('retorna 400 quando to está ausente', async () => {
    const res = await request(app)
      .post('/email')
      .send({ mode: 'text', serials });
    expect(res.status).toBe(400);
  });

  it('retorna 400 quando mode está ausente', async () => {
    const res = await request(app)
      .post('/email')
      .send({ to: 'a@b.com', serials });
    expect(res.status).toBe(400);
  });

  it('retorna 400 quando mode=attachment sem format', async () => {
    const res = await request(app)
      .post('/email')
      .send({ to: 'a@b.com', mode: 'attachment', serials });
    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });

  it('retorna 400 para mode inválido', async () => {
    const res = await request(app)
      .post('/email')
      .send({ to: 'a@b.com', mode: 'fax', serials });
    expect(res.status).toBe(400);
  });
});
