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
