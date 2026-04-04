jest.mock('../services/exporter', () => ({
  generate: jest.fn().mockResolvedValue({
    buffer: Buffer.from('fake pdf content'),
    mime: 'application/pdf',
    ext: 'pdf',
  }),
}));

jest.mock('../services/mailer', () => ({
  sendAsText: jest.fn().mockResolvedValue(undefined),
  sendWithAttachment: jest.fn().mockResolvedValue(undefined),
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

  it('retorna 400 quando format está ausente', async () => {
    const res = await request(app)
      .post('/export')
      .send({ serials });
    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });

  it('retorna 400 quando serials está ausente', async () => {
    const res = await request(app)
      .post('/export')
      .send({ format: 'pdf' });
    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });
});
