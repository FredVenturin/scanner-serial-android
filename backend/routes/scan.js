const express = require('express');
const router = express.Router();
const { extractText } = require('../services/ocr');
const { identifySerial } = require('../services/claude');

router.post('/', async (req, res) => {
  try {
    const { image } = req.body;
    if (!image) {
      return res.status(400).json({ error: 'image é obrigatório' });
    }

    const ocrText = await extractText(image);
    const serial = await identifySerial(ocrText);
    const confidence = serial === 'SERIAL_NAO_ENCONTRADO' ? 'low' : 'high';

    res.json({ serial, confidence });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
