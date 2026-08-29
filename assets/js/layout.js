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
let _configCache = null;
async function getConfig() {
  if (_configCache) return _configCache;
  try {
    const { data } = await supabaseClient.from('config').select('*').eq('id', 1).single();
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
    .select('rol, organizacion_id, nombre, email').eq('id', uid).maybeSingle();
  _perfilCache = data || null;
  return _perfilCache;
}

// Clínica que el súper-admin está administrando (impersonación), si hay.
function actingOrg() { try { return sessionStorage.getItem('sa_org') || null; } catch (e) { return null; } }
function actingOrgNombre() { try { return sessionStorage.getItem('sa_org_nombre') || ''; } catch (e) { return ''; } }
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
        ${impersonando ? `<button id="salir-clinica-btn" style="width:100%;margin-bottom:0.5rem;background:var(--color-accent);border:none;color:#1a2320;">← Volver a la Torre</button>` : ''}
        <button id="logout-btn" style="background:rgba(255,255,255,0.08);border:1px solid rgba(255,255,255,0.15);color:rgba(255,255,255,0.7);box-shadow:none;">Cerrar sesión</button>
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

  return session;
}
