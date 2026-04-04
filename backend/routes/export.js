const express = require('express');
const router = express.Router();
const { generate } = require('../services/exporter');

router.post('/', async (req, res) => {
  try {
    const { format, serials } = req.body;
    if (!format || !serials) {
      return res.status(400).json({ error: 'format e serials são obrigatórios' });
    }

    const { buffer, mime, ext } = await generate(format, serials);

    res.set({
      'Content-Type': mime,
      'Content-Disposition': `attachment; filename="seriais.${ext}"`,
    });
    res.send(buffer);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
