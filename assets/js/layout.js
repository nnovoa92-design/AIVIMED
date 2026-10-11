const NAV_ITEMS = [
  { section: 'Operaciones' },
  { key: 'dashboard',      icon: '⊞',  label: 'Inicio',           href: 'dashboard.html' },
  { key: 'pacientes',      icon: '♥',  label: 'Pacientes',         href: 'pacientes.html' },
  { key: 'agenda',         icon: '▦',  label: 'Agenda',            href: 'agenda.html' },
  { key: 'sesiones',       icon: '✎',  label: 'Fichas de sesión',  href: 'sesiones.html' },
  { key: 'consentimientos',icon: '✓',  label: 'Consentimientos',   href: 'consentimientos.html' },
  { key: 'cotizaciones',   icon: '▤',  label: 'Cotizaciones',      href: 'cotizaciones.html' },
  { section: 'Catálogos' },
  { key: 'servicios',      icon: '◈',  label: 'Servicios',         href: 'servicios.html' },
  { key: 'personal',       icon: '⚕',  label: 'Personal',          href: 'personal.html' },
  { key: 'stock',          icon: '⊡',  label: 'Stock',             href: 'stock.html' },
  { section: 'Administración' },
  { key: 'pagos',          icon: '$',  label: 'Pagos',             href: 'pagos.html' },
  { key: 'reportes',       icon: '◎',  label: 'Torre de Control',  href: 'reportes.html' },
  { key: 'configuracion',  icon: '⚙',  label: 'Configuración',     href: 'configuracion.html' },
];

// IVA Chile (default; se sobrescribe con el valor de la tabla config al llamar getConfig)
let IVA_PCT = 19;

// Configuración del centro (datos empresa + operacional), cacheada
let CONFIG_DEFAULT = {
  razon_social: 'AIVIMED', rut: '78.217.799-0',
  direccion: 'Aníbal Pinto 531, Of. 65, Concepción', correo: 'aivimed.salud@gmail.com',
  telefono: '', instagram: '', iva_pct: 19, politica_cotizacion: '',
  hora_apertura: '09:30', hora_cierre: '19:30', sab_apertura: '10:00', sab_cierre: '14:00',
};
// Horario por día (0 = domingo … 6 = sábado). Usa `horario_semana` de la configuración; si la
// clínica aún no lo definió, se deriva de las columnas antiguas (lun–vie, sábado; domingo cerrado).
// Misma lógica de respaldo que la función SQL horario_clinica().
const DIAS_NOMBRE = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
function horarioSemana(cfg) {
  const c = cfg || {};
  const h = (c.horario_semana && typeof c.horario_semana === 'object') ? c.horario_semana : null;
  const out = {};
  for (let i = 0; i < 7; i++) {
    const d = h && h[i];
    if (d && typeof d === 'object') {
      out[i] = { abierto: d.abierto === true, desde: d.desde || '09:30', hasta: d.hasta || '19:30' };
    } else if (i === 0) {
      out[i] = { abierto: false, desde: '10:00', hasta: '14:00' };
    } else if (i === 6) {
      out[i] = { abierto: true, desde: c.sab_apertura || '10:00', hasta: c.sab_cierre || '14:00' };
    } else {
      out[i] = { abierto: true, desde: c.hora_apertura || '09:30', hasta: c.hora_cierre || '19:30' };
    }
  }
  return out;
}

let _configCache = null;
async function getConfig(fresh) {
  if (_configCache && !fresh) return _configCache;
  try {
    // RLS ya limita la config a la clínica activa (la del usuario, o la que
    // el súper-admin está administrando). Puede no existir aún → defaults.
    const { data } = await supabaseClient.from('config').select('*').maybeSingle();
    _configCache = Object.assign({}, CONFIG_DEFAULT, data || {});
  } catch (e) {
    _configCache = Object.assign({}, CONFIG_DEFAULT);
  }
  IVA_PCT = Number(_configCache.iva_pct) || 19;
  return _configCache;
}

// Perfil del usuario actual (rol + organización), cacheado.
// Devuelve null si no se pudo determinar (para no provocar redirecciones erróneas).
let _perfilCache = null;
async function getMiPerfil() {
  if (_perfilCache) return _perfilCache;
  const { data: { session } } = await supabaseClient.auth.getSession();
  const uid = session && session.user && session.user.id;
  if (!uid) return null;
  const { data } = await supabaseClient.from('perfiles')
    .select('rol, organizacion_id, nombre, email, organizaciones(activo, plan, nombre)').eq('id', uid).maybeSingle();
  _perfilCache = data || null;
  return _perfilCache;
}

// Clínica que el súper-admin está administrando (impersonación), si hay.
function actingOrg() { try { return sessionStorage.getItem('sa_org') || null; } catch (e) { return null; } }
function actingOrgNombre() { try { return sessionStorage.getItem('sa_org_nombre') || ''; } catch (e) { return ''; } }
// Clínica "efectiva" en la que se está trabajando: la que administra el
// súper-admin (impersonación) o la del propio usuario.
async function orgEfectiva() {
  const imp = actingOrg();
  if (imp) return imp;
  const p = await getMiPerfil();
  return p && p.organizacion_id ? p.organizacion_id : null;
}
function salirDeClinica() {
  try { sessionStorage.removeItem('sa_org'); sessionStorage.removeItem('sa_org_nombre'); } catch (e) {}
  location.href = 'superadmin.html';
}

// Menú del súper-admin (dueño de la plataforma)
const NAV_SUPERADMIN = [
  { key: 'superadmin', icon: '◎', label: 'Torre de Control Global', href: 'superadmin.html' },
];

const METODOS_PAGO = {
  efectivo:        'Efectivo',
  tarjeta_debito:  'Tarjeta débito',
  tarjeta_credito: 'Tarjeta crédito',
  transferencia:   'Transferencia',
  otro:            'Otro',
};

const TIPOS_DOCUMENTO = {
  ninguno: 'Sin documento',
  boleta:  'Boleta',
  factura: 'Factura',
};

const ESTADOS_TURNO = {
  pendiente:   { label: 'Pendiente',   badge: 'badge-gray' },
  confirmado:  { label: 'Confirmado',  badge: 'badge-blue' },
  completado:  { label: 'Completado',  badge: 'badge-green' },
  cancelado:   { label: 'Cancelado',   badge: 'badge-red' },
  ausente:     { label: 'Ausente',     badge: 'badge-yellow' },
};

const ESTADOS_COTIZACION = {
  borrador:  { label: 'Por enviar', badge: 'badge-yellow' },
  enviada:   { label: 'Enviada',    badge: 'badge-blue' },
  aprobada:  { label: 'Aprobada',   badge: 'badge-green' },
  rechazada: { label: 'Rechazada',  badge: 'badge-red' },
};

function fmtNumero(prefijo, numero) {
  return `${prefijo}-${String(numero ?? 0).padStart(4, '0')}`;
}

function badgeEstado(estado, mapa) {
  const e = (mapa || {})[estado] || { label: estado, badge: 'badge-gray' };
  return `<span class="badge ${e.badge}">${e.label}</span>`;
}

// ---------- Campanita de novedades ----------
// Muestra, arriba a la derecha, las novedades que genera el paciente (reservas online,
// cotizaciones respondidas, consentimientos firmados a distancia). Cada novedad vive en la
// tabla `notificaciones`; si esa tabla aún no existe (falta v10), la campanita no aparece.
function haceTiempo(iso) {
  const seg = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
  if (seg < 60) return 'justo ahora';
  if (seg < 3600) return `hace ${Math.floor(seg / 60)} min`;
  if (seg < 86400) return `hace ${Math.floor(seg / 3600)} h`;
  if (seg < 172800) return 'ayer';
  return fmtFecha(iso);
}

function iniciarCampanita() {
  const topbar = document.querySelector('.topbar');
  if (!topbar || document.getElementById('campanita-btn')) return;
  const tituloBase = document.title;

  const btn = document.createElement('button');
  btn.type = 'button';
  btn.id = 'campanita-btn';
  btn.className = 'campanita';
  btn.setAttribute('aria-label', 'Novedades');
  btn.title = 'Novedades';
  btn.hidden = true;                       // se muestra cuando se confirma que la tabla existe
  btn.innerHTML = '🔔<span class="campanita-badge" id="campanita-badge" hidden>0</span>';
  topbar.appendChild(btn);

  const panel = document.createElement('div');
  panel.id = 'campanita-panel';
  panel.className = 'campanita-panel';
  panel.hidden = true;
  document.body.appendChild(panel);

  let items = [];
  let sinLeer = 0;
  let baseline = false;                    // la primera carga no cuenta como "nueva"
  const vistos = new Set();
  const permisoNavegador = () => ('Notification' in window) ? Notification.permission : 'unsupported';

  function pintarBadge() {
    const badge = document.getElementById('campanita-badge');
    badge.hidden = sinLeer === 0;
    badge.textContent = sinLeer > 99 ? '99+' : String(sinLeer);
    document.title = sinLeer > 0 ? `(${sinLeer}) ${tituloBase}` : tituloBase;
  }

  function pintarPanel() {
    const avisos = permisoNavegador();
    panel.innerHTML = `
      <div class="campanita-cab">
        <strong>Novedades</strong>
        <span>
          <button type="button" class="campanita-link" data-accion="leer-todas" ${sinLeer ? '' : 'disabled'}>Marcar todas como leídas</button>
        </span>
      </div>
      <div class="campanita-lista">
        ${items.length ? items.map(n => `
          <div class="campanita-item${n.leida ? '' : ' sin-leer'}" data-id="${n.id}">
            <div class="campanita-titulo">${htmlSeguro(n.titulo)}</div>
            ${n.detalle ? `<div class="campanita-detalle">${htmlSeguro(n.detalle)}</div>` : ''}
            <div class="campanita-hora">${haceTiempo(n.creado_en)}</div>
          </div>`).join('') : '<p class="campanita-vacio">Sin novedades por ahora.</p>'}
      </div>
      <div class="campanita-pie">
        ${avisos === 'default' ? '<button type="button" class="campanita-link" data-accion="activar-avisos">🔔 Activar avisos del navegador</button>' : ''}
        ${avisos === 'granted' ? '<span>✓ Avisos del navegador activos</span>' : ''}
        ${avisos === 'denied' ? '<span>Avisos del navegador bloqueados en este navegador</span>' : ''}
        ${items.some(n => n.leida) ? '<button type="button" class="campanita-link" data-accion="borrar-leidas">Borrar leídas</button>' : ''}
      </div>`;
  }

  async function cargar() {
    const { data, error } = await supabaseClient.from('notificaciones').select('*')
      .order('creado_en', { ascending: false }).limit(40);
    if (error) { btn.hidden = true; return; }          // falta v10: sin campanita
    btn.hidden = false;
    items = data || [];
    sinLeer = items.filter(n => !n.leida).length;

    // Avisos nuevos desde la última vez: aviso del navegador si la pestaña no está a la vista
    const nuevos = items.filter(n => !n.leida && !vistos.has(n.id));
    items.forEach(n => vistos.add(n.id));
    if (baseline && nuevos.length && permisoNavegador() === 'granted' && document.visibilityState === 'hidden') {
      nuevos.slice(0, 3).forEach(n => { try { new Notification(n.titulo, { body: n.detalle || '' }); } catch (e) { /* sin permiso real */ } });
    }
    baseline = true;
    pintarBadge();
    if (!panel.hidden) pintarPanel();
  }

  btn.addEventListener('click', (e) => {
    e.stopPropagation();
    panel.hidden = !panel.hidden;
    if (!panel.hidden) { pintarPanel(); cargar(); }
  });
  document.addEventListener('click', (e) => {
    if (!panel.hidden && !panel.contains(e.target) && !btn.contains(e.target)) panel.hidden = true;
  });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') panel.hidden = true; });

  panel.addEventListener('click', async (e) => {
    const accion = e.target.closest('[data-accion]');
    if (accion) {
      const a = accion.dataset.accion;
      if (a === 'leer-todas') {
        await supabaseClient.from('notificaciones').update({ leida: true }).eq('leida', false);
        await cargar();
      } else if (a === 'borrar-leidas') {
        await supabaseClient.from('notificaciones').delete().eq('leida', true);
        await cargar();
      } else if (a === 'activar-avisos') {
        try { await Notification.requestPermission(); } catch (err) { /* navegador sin soporte */ }
        pintarPanel();
      }
      return;
    }
    const fila = e.target.closest('.campanita-item');
    if (!fila) return;
    const n = items.find(x => x.id === fila.dataset.id);
    if (!n) return;
    if (!n.leida) await supabaseClient.from('notificaciones').update({ leida: true }).eq('id', n.id);
    if (n.url && /^[a-z0-9_-]+\.html$/i.test(n.url)) window.location.href = n.url;   // pantallas de /pages/
    else await cargar();
  });

  // Se mantiene al día sola: cada 45 s con la pestaña a la vista, y al volver a ella
  cargar();
  setInterval(() => { if (document.visibilityState === 'visible') cargar(); }, 45000);
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') cargar(); });
}

async function initLayout(activeKey) {
  const session = await requireAuth();
  if (!session) return null;

  // Rol del usuario → enrutamiento (a prueba de bucles):
  //  · súper-admin SIN clínica activa → Torre de Control Global
  //  · súper-admin CON clínica activa → usa la app normal, aislada a esa clínica
  //  · usuario de clínica → nunca entra al panel de súper-admin
  const perfil = await getMiPerfil();
  const esSuperadmin = !!perfil && perfil.rol === 'superadmin';
  const impersonando = esSuperadmin && !!actingOrg();
  // Cloudflare puede servir sin ".html" (/pages/superadmin). Detectamos por
  // el nombre, no por la extensión, para no caer en un bucle de redirección.
  const enSuperadmin = /superadmin/.test(location.pathname);

  if (esSuperadmin) {
    if (!impersonando && !enSuperadmin) { location.replace('superadmin.html'); return null; }
  } else if (perfil) {
    if (enSuperadmin) { location.replace('dashboard.html'); return null; }
    // Bloqueo: clínica desactivada o suspendida no puede operar.
    const org = perfil.organizaciones || {};
    const bloqueada = (org.activo === false) || (org.plan === 'suspendido');
    if (bloqueada) {
      await supabaseClient.auth.signOut();
      alert('El acceso de tu clínica está suspendido. Por favor, contacta al administrador de la plataforma.');
      location.replace('/index.html');
      return null;
    }
  }

  const menu = (esSuperadmin && !impersonando) ? NAV_SUPERADMIN : NAV_ITEMS;

  const sidebar = document.getElementById('sidebar');
  if (sidebar) {
    const navLinks = menu.map(item => {
      if (item.section) return `<div class="nav-section">${item.section}</div>`;
      const cls = item.key === activeKey ? ' class="active"' : '';
      const iconSpan = item.icon ? `<span style="font-style:normal;font-size:1rem;opacity:0.7;width:1.2rem;text-align:center;">${item.icon}</span>` : '';
      return `<a href="${item.href}"${cls}>${iconSpan}${item.label}</a>`;
    }).join('');

    const logoTag = `<img class="brand-logo" src="../assets/img/logo.png" alt="" onerror="this.style.display='none'">`;
    const brandTxt = impersonando
      ? `<span>${actingOrgNombre() || 'Clínica'}<span class="brand-sub">Administrando</span></span>`
      : esSuperadmin
        ? `<span>Plataforma<span class="brand-sub">Súper-Admin</span></span>`
        : `<span>AIVIMED<span class="brand-sub">Salud Integral</span></span>`;
    sidebar.innerHTML = `
      <div class="brand">
        ${logoTag}${brandTxt}
      </div>
      <nav>${navLinks}</nav>
      <div class="sidebar-footer">
        ${impersonando ? `<button id="salir-clinica-btn" style="width:100%;margin-bottom:0.5rem;background:var(--color-accent);border:none;color:#3d2f0a;">← Volver a la Torre</button>` : ''}
        <button id="logout-btn" class="btn-secondary" style="width:100%;">Cerrar sesión</button>
      </div>
    `;

    document.getElementById('logout-btn').addEventListener('click', logout);
    if (impersonando) {
      const sc = document.getElementById('salir-clinica-btn');
      if (sc) sc.addEventListener('click', salirDeClinica);
    }

    // Banner cuando el súper-admin está administrando una clínica
    if (impersonando) {
      const tb = document.querySelector('.topbar');
      if (tb && !document.getElementById('impersonar-banner')) {
        const b = document.createElement('div');
        b.id = 'impersonar-banner';
        b.style.cssText = 'background:var(--color-accent);color:#1a2320;font-size:0.82rem;font-weight:600;padding:0.35rem 1rem;text-align:center;';
        b.innerHTML = `Estás administrando la clínica: ${actingOrgNombre() || ''} — todos los cambios afectan solo a esta clínica.`;
        tb.parentNode.insertBefore(b, tb.nextSibling);
      }
    }

    const shell = sidebar.closest('.app-shell');
    const topbar = document.querySelector('.topbar');
    if (shell && topbar && !document.querySelector('.menu-toggle')) {
      const btn = document.createElement('button');
      btn.className = 'menu-toggle';
      btn.setAttribute('aria-label', 'Abrir menú');
      btn.textContent = '☰';
      topbar.insertBefore(btn, topbar.firstChild);

      const backdrop = document.createElement('div');
      backdrop.className = 'sidebar-backdrop';
      shell.appendChild(backdrop);

      const cerrar = () => shell.classList.remove('nav-open');
      btn.addEventListener('click', () => shell.classList.toggle('nav-open'));
      backdrop.addEventListener('click', cerrar);
      sidebar.querySelectorAll('nav a').forEach(a => a.addEventListener('click', cerrar));
    }
  }

  // Campanita: el súper-admin sin clínica activa no tiene novedades que ver
  if (!esSuperadmin || impersonando) iniciarCampanita();

  return session;
}
