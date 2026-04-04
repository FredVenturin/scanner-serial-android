const mockTextDetection = jest.fn().mockResolvedValue([{
  textAnnotations: [{ description: 'SN: 00X7482K\nModel: Dell XPS' }]
}]);

jest.mock('@google-cloud/vision', () => {
  return {
    ImageAnnotatorClient: jest.fn().mockImplementation(() => ({
      textDetection: mockTextDetection
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
    mockTextDetection.mockResolvedValueOnce([{ textAnnotations: [] }]);
    const result = await extractText('base64imagestring');
    expect(result).toBe('');
  });
});
