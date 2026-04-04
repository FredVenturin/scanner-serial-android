jest.mock('../services/ocr', () => ({
  extractText: jest.fn().mockResolvedValue('SN: 00X7482K Model: Dell XPS'),
}));

jest.mock('../services/claude', () => ({
  identifySerial: jest.fn().mockResolvedValue('SN-00X7482K'),
}));

jest.mock('../services/mailer', () => ({
  sendAsText: jest.fn().mockResolvedValue(undefined),
  sendWithAttachment: jest.fn().mockResolvedValue(undefined),
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
