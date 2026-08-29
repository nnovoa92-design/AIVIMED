# Bitácora de cambios — AIVIMED

Registro cronológico de lo construido. Lo más reciente arriba.

## 2026-07
- **Carpeta RESPALDO** creada (PROYECTO.md, RESPALDO.md, BITACORA.md) como respaldo maestro del proyecto.
- **Configuración:** al elegir un servicio, el cuadro de consentimiento precarga el texto estándar del procedimiento (antes salía en blanco). Botón "Restaurar texto estándar".
- **Reserva online:** al tocar un servicio avanza solo; WhatsApp al número de AIVIMED + botón de correo; estructura EmailJS lista (sin activar).
- **Reserva online:** toma horarios de Configuración; turnos marcados `origen='online'`; enlace de reserva para redes en la Agenda.
- **Agenda:** corregido desfase de zona horaria (los turnos no aparecían). Recuperación de turnos viejos con `AT TIME ZONE`.
- **Consentimientos:** firma visible al imprimir (ventana nueva) + registro auditable (fecha/dispositivo/IP).
- **Consentimientos:** texto editable en el momento con numeración de renglones.
- **Consentimientos:** plantillas por procedimiento, firma remota, registro auditable; fix del selector de servicio.
- **Menú Configuración:** datos de empresa, operacional (IVA, horarios, política), plantillas de consentimiento.
- **Sesiones:** packs/tratamientos + cuadro de avance + fotos; 2ª profesional de apoyo.
- **Pagos:** documentos (boleta/factura) + IVA + vínculo a cotización.
- **Cotizaciones:** IVA opcional, aceptar/agendar, compartir WhatsApp/correo, PDF por ventana de impresión, datos de empresa y paciente en el documento.
- **Torre de Control** (ex Reportes) con resumen tributario.
- **Idioma** pasado a español latinoamericano neutro.
- **Branding AIVIMED** (Cinzel Decorative, verde #439974 + dorado), logo, rediseño.
- **Deploy** en Cloudflare + repo GitHub. Supabase en schema `bienestar`.
- **Base inicial:** login, dashboard, pacientes, agenda, servicios (catálogo real), personal, stock, pagos, reportes, historial, reserva pública.
