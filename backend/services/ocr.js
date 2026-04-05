const vision = require('@google-cloud/vision');

let clientOptions = {};
if (process.env.GOOGLE_CREDENTIALS_JSON) {
  const credentials = JSON.parse(process.env.GOOGLE_CREDENTIALS_JSON);
  clientOptions = { credentials };
}
const client = new vision.ImageAnnotatorClient(clientOptions);

async function extractText(base64Image) {
  const [result] = await client.textDetection({
    image: { content: base64Image },
  });
  const annotations = result.textAnnotations;
  if (!annotations || annotations.length === 0) return '';
  return annotations[0].description;
}

module.exports = { extractText };
