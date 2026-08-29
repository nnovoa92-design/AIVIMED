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

## 10. Pendientes / próximos pasos
- Definir con AIVIMED la **política de cotización** (cuestionario enviado) → cargarla en Configuración.
- **Dominio propio** aivimed.cl (comprar en NIC Chile → nameservers de Cloudflare).
- **Landing pública** de publicidad (la plataforma actual es solo operacional).
- **Correo automático** de reservas (EmailJS: falta que AIVIMED cree cuenta y dé las claves) — código ya preparado en reservar.html (`EMAILJS_CONFIG`).
- Respaldo de **datos** (no solo código): ver `RESPALDO/RESPALDO.md`.

## 11. Respaldo de datos (base de datos)
El código está respaldado en GitHub. Los **datos** (pacientes, turnos, etc.) viven en Supabase.
Ver `RESPALDO/RESPALDO.md` para cómo exportarlos.
