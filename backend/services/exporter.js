const PDFDocument = require('pdfkit');
const ExcelJS = require('exceljs');
const { Document, Packer, Paragraph, TextRun } = require('docx');

async function generateTxt(serials) {
  const lines = serials.map((item, i) => {
    const note = item.note ? ` — ${item.note}` : '';
    return `${i + 1}. ${item.serial}${note}`;
  });
  return Buffer.from(lines.join('\n'), 'utf-8');
}

async function generatePdf(serials) {
  return new Promise((resolve) => {
    const doc = new PDFDocument({ margin: 40 });
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));

    doc.fontSize(18).font('Helvetica-Bold').text('Lista de Seriais', { align: 'center' });
    doc.moveDown();

    serials.forEach((item, i) => {
      const note = item.note ? ` — ${item.note}` : '';
      doc.fontSize(12).font('Helvetica').text(`${i + 1}. ${item.serial}${note}`);
    });

    doc.end();
  });
}

async function generateXlsx(serials) {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Seriais');
  sheet.columns = [
    { header: '#', key: 'index', width: 6 },
    { header: 'Número de Série', key: 'serial', width: 28 },
    { header: 'Observação', key: 'note', width: 40 },
  ];
  sheet.getRow(1).font = { bold: true };
  serials.forEach((item, i) => {
    sheet.addRow({ index: i + 1, serial: item.serial, note: item.note || '' });
  });
  const buffer = await workbook.xlsx.writeBuffer();
  return Buffer.from(buffer);
}

async function generateDocx(serials) {
  const paragraphs = [
    new Paragraph({
      children: [new TextRun({ text: 'Lista de Seriais', bold: true, size: 32 })],
      spacing: { after: 200 },
    }),
    ...serials.map((item, i) => {
      const note = item.note ? ` — ${item.note}` : '';
      return new Paragraph({
        children: [new TextRun({ text: `${i + 1}. ${item.serial}${note}`, size: 24 })],
      });
    }),
  ];

  const doc = new Document({ sections: [{ children: paragraphs }] });
  return Packer.toBuffer(doc);
}

const FORMATS = {
  txt:  { fn: generateTxt,  mime: 'text/plain', ext: 'txt' },
  pdf:  { fn: generatePdf,  mime: 'application/pdf', ext: 'pdf' },
  xlsx: { fn: generateXlsx, mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', ext: 'xlsx' },
  docx: { fn: generateDocx, mime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', ext: 'docx' },
};

async function generate(format, serials) {
  if (!FORMATS[format]) throw new Error(`Formato inválido: ${format}`);
  const { fn, mime, ext } = FORMATS[format];
  const buffer = await fn(serials);
  return { buffer, mime, ext };
}

module.exports = { generate };
