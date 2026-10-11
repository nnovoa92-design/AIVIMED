# AIVIMED — Libro del proyecto (respaldo maestro)

> Documento único de verdad del sistema. Se actualiza con cada cambio.
> Última actualización: 2026-07 (sesión de desarrollo con Claude).

## 1. Qué es
Sistema de gestión para **AIVIMED**, centro de enfermería y estética integral (Concepción, Chile).
Uso **operacional interno** (dueñas/equipo). Aparte tiene páginas públicas para pacientes.

## 2. Datos de la empresa
- Razón social: **AIVIMED** · RUT **78.217.799-0**
- Dirección: **Aníbal Pinto 531, Of. 65, Concepción**
- Correo: **aivimed.salud@gmail.com**
- Eslogan: "Salud Integral"
- Horarios: Lun–Vie **09:30–19:30**, Sábado **10:00–14:00** (editables en Configuración). Domingo cerrado.
- Estos datos hoy se editan en **Configuración** (tabla `config`).

## 3. Dónde vive todo
- **Carpeta local:** `C:\Users\Nicolás\Desktop\Centro Bienestar — Sistema de Gestión\`
- **Repo GitHub (respaldo del código):** https://github.com/nnovoa92-design/AIVIMED (rama `main`)
- **Sitio en vivo (Cloudflare, deploy automático al hacer push):** https://aivimed.nnovoa92.workers.dev/
- **Usuario git:** Nicolás Novoa · nnovoa92@gmail.com
- ⚠️ **Usar SIEMPRE la URL publicada** para trabajar, NO abrir los archivos como `file://` (rompe los enlaces compartidos).

## 4. Stack y arquitectura
- HTML/CSS/JS plano, **sin build tools**. Un archivo HTML por página.
- Backend: **Supabase** (Auth + Postgres + Storage).
- CSS común: `assets/css/style.css`. Lógica común: `assets/js/layout.js` (sidebar, helpers, getConfig, IVA_PCT). Cliente: `assets/js/supabaseClient.js`.
- Deploy: `git push` → Cloudflare reconstruye solo.

## 5. Supabase (importante)
- Proyecto COMPARTIDO con otro proyecto ("mundial"). URL: `https://qaeeqdfolgjobwxdpojd.supabase.co`
- Para no chocar, AIVIMED vive en el **schema `bienestar`** (no `public`). El cliente JS usa `db: { schema: 'bienestar' }`.
- El schema `bienestar` está **expuesto en Data API** (Settings → API → Exposed schemas).
- Usuario operacional: **aivimed.salud@gmail.com**.
- **Reglas SQL del proyecto:**
  - Bajo `set search_path to bienestar` NO existe `uuid_generate_v4()`. Usar **`gen_random_uuid()`**.
  - En `VALUES` con `null` mezclado, castear (`s.precio::numeric`).
  - Las funciones públicas (para páginas sin login) son **SECURITY DEFINER** con `grant execute ... to anon`.

## 6. Módulos (páginas internas, en pages/)
- **dashboard** — inicio, stats (turnos hoy, pacientes, stock bajo, ingresos mes) + logo/hero.
- **pacientes** — ABM + búsqueda. Botón "Historial" por paciente.
- **agenda** — vistas **día / semana / mes**. Slots de 1h según horarios de Configuración. Acepta `?paciente=ID` para precargar (desde cotización aceptada). Marca **ONLINE** los turnos de reserva pública. Tarjeta con enlace de reserva para redes.
- **sesiones** (Fichas de sesión) — **packs/tratamientos** (N sesiones mismo paciente/procedimiento) con **cuadro de avance** (realizadas/restantes/próxima), **profesional líder + 2ª de apoyo**, y **fotos** (Supabase Storage bucket `sesiones`).
- **consentimientos** — plantillas por procedimiento (editables, con numeración de renglones), firma **en sala** o **remota** (enlace que el paciente firma en su celular), **registro auditable** (fecha/hora + dispositivo + IP). Imprime en ventana nueva.
- **cotizaciones** — ítems del catálogo, **IVA 19% opcional**, estado automático **Por enviar → Enviada** (al compartir) → Aprobada/Rechazada. Compartir por **WhatsApp/correo** con enlace de respuesta pública. Al aceptar ofrece **agendar**. PDF vía ventana de impresión. Botón **+ Nuevo paciente** inline.
- **servicios** — catálogo + categorías + campo `consentimiento_template` por servicio.
- **personal** — profesionales (sin campo Matrícula).
- **stock** — insumos + movimientos entrada/salida.
- **pagos** — cobros con **tipo de documento (boleta/factura)**, **IVA**, y vínculo a cotización (evita duplicar ingresos). El monto YA incluye IVA (se desglosa hacia atrás).
- **reportes = "Torre de Control"** — KPIs con íconos, resumen tributario (IVA débito, ventas netas), por método/documento, top servicios/pacientes.
- **historial** — vista clínica unificada por paciente (sesiones, turnos, pagos).
- **configuracion** — 3 secciones: **datos de empresa**, **operacional** (IVA, horarios, política de cotización), y **plantillas de consentimiento** por servicio (precarga el texto estándar del procedimiento para editar y guardar como predeterminado).

## 7. Páginas públicas (en la raíz, sin login)
- **reservar.html** — auto-reserva de pacientes para redes sociales. Catálogo en vivo (mismos servicios activos), calendario, horarios de Configuración. Al elegir servicio avanza solo. Turno entra como `pendiente` + `origen='online'`. Confirmación con WhatsApp al número de AIVIMED y correo. (EmailJS preparado, sin activar).
- **respuesta.html** — el paciente ve su cotización y responde Aceptar/Rechazar/Observación.
- **firmar-consentimiento.html** — el paciente firma su consentimiento desde el celular.

## 8. Convenciones y decisiones tomadas (no volver a preguntar)
- **Idioma:** español **latinoamericano neutro** (formas con "tú": selecciona, puedes, agrega…). NO voseo rioplatense.
- **PDF/impresión:** se hace por **ventana de impresión** (window.print en ventana nueva), NO html2pdf/html2canvas (generaba PDFs en blanco).
- **Moneda:** CLP, formato `es-CL`.
- **IVA:** 19%, configurable en `config.iva_pct`. En cotizaciones se SUMA al neto; en pagos el monto YA lo incluye.
- **Fechas/horas:** guardar el instante con zona (`new Date(valorLocal).toISOString()`); mostrar en hora local; construir fechas con componentes locales (helper `ymd`), NO `toISOString().slice(0,10)`. Evita el desfase que hacía "desaparecer" turnos.
- **Enlaces compartidos:** usan `SITE_BASE` = origin si es http(s), si no caen al dominio de Cloudflare (para que funcionen aunque se abra como archivo local).
- **Logo:** `assets/img/logo.png` (mariposa, fondo verde). En PDFs se incrusta como data URI.
- **Marca/tipografía:** nombre AIVIMED en **Cinzel Decorative**; títulos Playfair Display italic; cuerpo DM Sans. Colores: verde `#439974` + dorado `#c5a44e`.
- **Fotos de sesión:** bucket público con nombres aleatorios (pendiente pasar a privado con URLs firmadas si se quiere más privacidad).

## 9. Migraciones SQL (en carpeta sql/) — orden de ejecución
1. `schema.sql` — tablas base (perfiles, pacientes, servicios, personal, turnos, sesiones, insumos, pagos…).
2. `catalogo_real.sql` — 45 servicios reales con precios/descripciones.
3. `cotizaciones.sql` — cotizaciones + cotizacion_items.
4. `v2_sesiones_iva_documentos.sql` — sesiones.personal_apoyo_id, cotizaciones.con_iva, pagos.(con_iva/tipo_documento/cotizacion_id).
5. `v3_respuesta_cotizacion.sql` — cotizaciones.observacion + RPC obtener/responder cotización.
6. `v4_tratamientos_fotos.sql` — tabla tratamientos + sesiones.(tratamiento_id/numero_sesion) + bucket Storage `sesiones`.
7. `v5_consentimientos.sql` — servicios.consentimiento_template, consentimientos.firmado_en + RPC obtener/firmar consentimiento.
8. `v6_config.sql` — tabla `config` (empresa + operacional).
9. `v7_firma_auditoria.sql` — consentimientos.(firma_user_agent/firma_ip) + RPC firmar con auditoría.
10. `v8_origen_turno.sql` — turnos.origen (interno/online).
11. `saas/02`–`saas/06` — multi-clínica (ver BITACORA 2026-07/08): organizaciones, RLS por `current_org()`, súper-admin/impersonación, páginas públicas por slug.
12. `v9_unificar_rut_telefono.sql` — RUT único POR CLÍNICA (antes global) + unifica formato de RUT/teléfonos ya guardados (respaldo en `respaldo_formatos`).
13. `v10_notificaciones.sql` — tabla `notificaciones` (RLS por clínica) + triggers: reserva online nueva, cotización aceptada/rechazada, consentimiento firmado a distancia. Alimenta la campanita 🔔 (`iniciarCampanita()` en layout.js).
14. `v11_reserva_reconoce_paciente.sql` — RPC públicas `reservar_reconocer` (datos censurados + límite por IP) y `crear_reserva_v2` (asocia por RUT); tabla interna `reservar_consultas_rut`.
15. `v12_horarios_bloqueos.sql` — `config.horario_semana` (jsonb 0..6), tabla `bloqueos_agenda` (RLS por clínica), `horario_clinica()`, `ocupacion_publica()`, `datos_reserva_publica` con horario por día, y `crear_reserva_v2` con validación de día/horario/bloqueos/choques + limpieza de texto.

16. `v13_notificacion_turno.sql` — `notificaciones.turno_id` (FK a turnos, on delete cascade) y trigger de reserva online que lo guarda; permite el botón "Confirmar y enviar mensaje" en la campanita.

### Decisiones del dueño (2026-10)
- RUT obligatorio en la reserva online: no se atiende a extranjeros sin RUT / no formalizados.
- Por ahora una sola clínica (AIVIMED): el multi-clínica queda construido pero sin uso; no se priorizan ajustes para más clínicas.

### Horarios, bloqueos y confirmación (decisión 2026-10)
- **Horario por día** (lunes a domingo, cada uno abierto/cerrado con su apertura y cierre) en Configuración; la agenda y la reserva pública lo leen de inmediato (la agenda se refresca sola cada 45 s). Un día cerrado no se puede reservar online.
- **Bloqueos**: por hora/tramo, día o semana; no se reservan online y se marcan en la agenda. Los turnos ocupan tantas horas como su duración (selector en horas).
- **Confirmar** un turno abre un mensaje listo para el paciente con las horas reservadas, sin pedir cédula; el envío es 1 clic por WhatsApp (no hay envío 100% automático sin WhatsApp Business API).
- Reserva online: reserva provisoriamente la duración del servicio en horas completas; la clínica define las horas finales al confirmar.

### Reconocer al paciente por RUT (decisión 2026-10)
- **Agenda interna:** casilla RUT en "Nuevo turno"; RUT existente → ficha; nuevo → se crea junto con el turno; teléfono repetido sin RUT → se completa el RUT en vez de duplicar.
- **Reserva pública:** el RUT va primero; paciente conocida ve solo primer nombre y `•••• 5678`, con opción de otro teléfono. Si faltan las RPC (v11), cae al formulario clásico.
- **Campanita:** solo avisa lo que hace el paciente desde links públicos; lo del equipo con sesión no.

### Formato de RUT y teléfono (decisión 2026-10)
- Un solo formato en toda la app, vía `assets/js/formatos.js`: RUT `12.345.678-9`, teléfono `+56 9 1234 5678`. Se aplica por id de casilla / `type="tel"` (ver BITACORA). El RUT vive en la columna `pacientes.dni`.
- Privacidad en páginas públicas (regla fija): nunca mostrar datos personales completos a quien solo escribe un RUT; solo primer nombre y `•••• 5678`, con opción de indicar otro teléfono.

## 10. Pendientes / próximos pasos
- Definir con AIVIMED la **política de cotización** (cuestionario enviado) → cargarla en Configuración.
- **Dominio propio** aivimed.cl (comprar en NIC Chile → nameservers de Cloudflare).
- **Landing pública** de publicidad (la plataforma actual es solo operacional).
- **Correo automático** de reservas (EmailJS: falta que AIVIMED cree cuenta y dé las claves) — código ya preparado en reservar.html (`EMAILJS_CONFIG`).
- Respaldo de **datos** (no solo código): ver `RESPALDO/RESPALDO.md`.

## 11. Respaldo de datos (base de datos)
El código está respaldado en GitHub. Los **datos** (pacientes, turnos, etc.) viven en Supabase.
Ver `RESPALDO/RESPALDO.md` para cómo exportarlos.
