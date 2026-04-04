const { Resend } = require('resend');
const resend = new Resend(process.env.RESEND_API_KEY);

async function sendAsText(to, serials) {
  const lines = serials.map((item, i) => {
    const note = item.note ? ` — ${item.note}` : '';
    return `${i + 1}. ${item.serial}${note}`;
  });

  await resend.emails.send({
    from: process.env.EMAIL_FROM,
    to,
    subject: 'Lista de Seriais — Scanner',
    text: `Seriais escaneados:\n\n${lines.join('\n')}\n\nTotal: ${serials.length} serial(is)\nEnviado via Scanner de Série`,
  });
}

async function sendWithAttachment(to, buffer, format, ext, mime) {
  await resend.emails.send({
    from: process.env.EMAIL_FROM,
    to,
    subject: 'Lista de Seriais — Scanner',
    html: '<p>Segue em anexo a lista de seriais escaneados.</p>',
    attachments: [
      {
        filename: `seriais.${ext}`,
        content: buffer.toString('base64'),
      },
    ],
  });
}

module.exports = { sendAsText, sendWithAttachment };
