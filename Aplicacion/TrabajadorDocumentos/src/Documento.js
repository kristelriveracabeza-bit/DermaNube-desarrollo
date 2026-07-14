import { PDFDocument, StandardFonts, rgb } from "pdf-lib"

export async function generarDocumento(datos) {
  const documento = await PDFDocument.create()
  const pagina = documento.addPage([595, 842])
  const fuente = await documento.embedFont(StandardFonts.Helvetica)
  const negrita = await documento.embedFont(StandardFonts.HelveticaBold)
  pagina.drawText("DermaNube", { x: 52, y: 780, size: 22, font: negrita, color: rgb(.11, .10, .22) })
  pagina.drawText("Confirmación de atención dermatológica", { x: 52, y: 735, size: 17, font: negrita })
  pagina.drawText(`Cita: ${datos.id || "Sin identificador"}`, { x: 52, y: 690, size: 12, font: fuente })
  pagina.drawText(`Paciente: ${datos.pacienteId || "Sin paciente"}`, { x: 52, y: 665, size: 12, font: fuente })
  pagina.drawText(`Especialista: ${datos.especialistaNombre || datos.especialistaId || "Sin especialista"}`, { x: 52, y: 640, size: 12, font: fuente })
  pagina.drawText(`Fecha: ${datos.fechaHora || "Sin fecha"}`, { x: 52, y: 615, size: 12, font: fuente })
  pagina.drawText(`Modalidad: ${datos.modalidad || "Presencial"}`, { x: 52, y: 590, size: 12, font: fuente })
  pagina.drawText("Este documento confirma el registro de la cita y no reemplaza una receta médica.", { x: 52, y: 530, size: 10, font: fuente, maxWidth: 480 })
  return documento.save()
}
