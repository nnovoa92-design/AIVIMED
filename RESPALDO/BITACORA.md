# Bitácora de cambios — AIVIMED

Registro cronológico de lo construido. Lo más reciente arriba.

## 2026-07
- **Torre de Control Global (súper-admin):** pages/superadmin.html — KPIs globales, lista de clínicas con conteos, crear clínica, y asignar usuarios a clínicas (RPC sa_asignar_usuario, SQL saas/03). layout.js detecta rol (getMiPerfil) y enruta: súper-admin → superadmin.html; usuarios de clínica no entran ahí. index.html redirige por rol al iniciar sesión. Migración in-place ejecutada OK; súper-admin creado.
- **SaaS multi-clínica (EN CURSO):** decisión de convertir AIVIMED en plataforma multi-tenant para vender a otras clínicas. Proyecto Supabase DEDICADO (nuevo, separado del "mundial"). Empezando por la base de seguridad. Esquema en `sql/saas/01_schema_multitenant.sql` (organizaciones + perfiles con roles superadmin/admin/profesional/recepcion + organizacion_id en cada tabla + RLS de aislamiento con current_org()/is_superadmin()). Pendiente: crear proyecto nuevo, migrar datos de AIVIMED como 1ª organización, adaptar app a tenant, torre de control súper-admin, endurecimiento (storage privado, funciones públicas por org).
- **Plantilla de consentimiento Ácido Hialurónico** cargada desde el formulario real de AIVIMED + puntos legales agregados (veracidad, contraindicaciones ampliadas, Ley 19.628, derecho a revocar, autorización publicitaria separada/opcional). Archivo: `sql/plantilla_acido_hialuronico.sql`. NOTA: cuando la clienta envíe formularios reales de otros procedimientos, transcribirlos igual como plantilla del servicio correspondiente.
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
