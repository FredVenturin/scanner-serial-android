require('dotenv').config();
const express = require('express');
const cors = require('cors');

const scanRoute = require('./routes/scan');
const exportRoute = require('./routes/export');
const emailRoute = require('./routes/email');

const app = express();
app.use(cors({ origin: false }));
app.use(express.json({ limit: '10mb' }));

app.use('/scan', scanRoute);
app.use('/export', exportRoute);
app.use('/email', emailRoute);

const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, () => console.log(`Backend rodando na porta ${PORT}`));
}

module.exports = app;
