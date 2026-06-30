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
];

// IVA Chile
const IVA_PCT = 19;

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

  const sidebar = document.getElementById('sidebar');
  if (sidebar) {
    const navLinks = NAV_ITEMS.map(item => {
      if (item.section) return `<div class="nav-section">${item.section}</div>`;
      const cls = item.key === activeKey ? ' class="active"' : '';
      const iconSpan = item.icon ? `<span style="font-style:normal;font-size:1rem;opacity:0.7;width:1.2rem;text-align:center;">${item.icon}</span>` : '';
      return `<a href="${item.href}"${cls}>${iconSpan}${item.label}</a>`;
    }).join('');

    const logoTag = `<img class="brand-logo" src="../assets/img/logo.png" alt="" onerror="this.style.display='none'">`;
    sidebar.innerHTML = `
      <div class="brand">
        ${logoTag}<span>AIVIMED<span class="brand-sub">Salud Integral</span></span>
      </div>
      <nav>${navLinks}</nav>
      <div class="sidebar-footer">
        <button id="logout-btn" style="background:rgba(255,255,255,0.08);border:1px solid rgba(255,255,255,0.15);color:rgba(255,255,255,0.7);box-shadow:none;">Cerrar sesión</button>
      </div>
    `;

    document.getElementById('logout-btn').addEventListener('click', logout);

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
