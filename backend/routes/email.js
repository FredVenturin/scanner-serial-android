const express = require('express');
const router = express.Router();
const { generate } = require('../services/exporter');
const { sendAsText, sendWithAttachment } = require('../services/mailer');

router.post('/', async (req, res) => {
  try {
    const { to, mode, format, serials } = req.body;

    if (!to || !mode || !serials) {
      return res.status(400).json({ error: 'to, mode e serials são obrigatórios' });
    }

    if (mode === 'text') {
      await sendAsText(to, serials);
    } else if (mode === 'attachment') {
      if (!format) {
        return res.status(400).json({ error: 'format é obrigatório para mode=attachment' });
      }
      const { buffer, mime, ext } = await generate(format, serials);
      await sendWithAttachment(to, buffer, format, ext, mime);
    } else {
      return res.status(400).json({ error: 'mode deve ser "text" ou "attachment"' });
    }

    res.json({ success: true, message: `E-mail enviado para ${to}` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
