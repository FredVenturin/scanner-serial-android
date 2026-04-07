const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT) || 587,
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  connectionTimeout: 10000,
  greetingTimeout: 10000,
  socketTimeout: 10000,
});

async function sendAsText(to, serials) {
  const lines = serials.map((item, i) => {
    const note = item.note ? ` — ${item.note}` : '';
    return `${i + 1}. ${item.serial}${note}`;
  });

  await transporter.sendMail({
    from: process.env.SMTP_USER,
    to,
    subject: 'Lista de Seriais — Scanner',
    text: `Seriais escaneados:\n\n${lines.join('\n')}\n\nTotal: ${serials.length} serial(is)\nEnviado via Scanner de Série`,
  });
}

async function sendWithAttachment(to, buffer, format, ext, mime) {
  await transporter.sendMail({
    from: process.env.SMTP_USER,
    to,
    subject: 'Lista de Seriais — Scanner',
    html: '<p>Segue em anexo a lista de seriais escaneados.</p>',
    attachments: [
      {
        filename: `seriais.${ext}`,
        content: buffer,
        contentType: mime,
      },
    ],
  });
}

module.exports = { sendAsText, sendWithAttachment };
