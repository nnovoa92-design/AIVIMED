// assets/js/formatos.js — formato único de RUT y teléfono (Chile). Sin dependencias.
// Incluir con <script src="../assets/js/formatos.js"></script> ANTES de layout.js en las
// páginas internas, y con <script src="assets/js/formatos.js"></script> en las públicas.

// Texto del usuario listo para meter en HTML (sin interpretar etiquetas).
function htmlSeguro(s) {
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function rutLimpio(valor) {
  return String(valor == null ? '' : valor).replace(/[^0-9kK]/g, '').toUpperCase();
}

function formatearRut(valor) {
  const crudo = String(valor == null ? '' : valor);
  // Pasaportes u otros documentos con letras: no se tocan
  if (/[A-JL-Z]/i.test(crudo)) return crudo;
  const v = rutLimpio(crudo);
  if (v.length < 2) return v;
  const cuerpo = v.slice(0, -1).replace(/\D/g, '').replace(/^0+(?=\d)/, '');
  return cuerpo.replace(/\B(?=(\d{3})+(?!\d))/g, '.') + '-' + v.slice(-1);
}

// Dígito verificador (módulo 11). Acepta cuerpos de 6 a 8 dígitos.
function rutValido(valor) {
  const v = rutLimpio(valor);
  if (v.length < 7 || v.length > 9) return false;
  const cuerpo = v.slice(0, -1);
  if (!/^\d+$/.test(cuerpo)) return false;
  let suma = 0, mul = 2;
  for (let i = cuerpo.length - 1; i >= 0; i--) {
    suma += Number(cuerpo[i]) * mul;
    mul = mul === 7 ? 2 : mul + 1;
  }
  const r = 11 - (suma % 11);
  const esperado = r === 11 ? '0' : r === 10 ? 'K' : String(r);
  return v.slice(-1) === esperado;
}

// Formato único del teléfono: "+56 9 1234 5678" (celular), "+56 2 1234 5678" (fijo de Santiago) o
// "+56 41 234 5678" (fijo de región). Un número de otro país (+51, +54…) se deja como se escribió.
// `borrando` evita que el prefijo "+56" quede pegado cuando se borra con la tecla retroceso.
function agruparNacional(n) {
  const grupos = (s) => s.match(/.{1,4}/g) || [];
  if (n.startsWith('9')) return n.length <= 1 ? n : '9 ' + grupos(n.slice(1)).join(' ');
  if (n.startsWith('2')) return n.length <= 1 ? n : '2 ' + grupos(n.slice(1)).join(' ');
  return [n.slice(0, 2), n.slice(2, 5), n.slice(5, 9)].filter(Boolean).join(' ');
}

function formatearTelefonoCL(valor, borrando) {
  let crudo = String(valor == null ? '' : valor).trim();
  if (/^00\d/.test(crudo)) crudo = '+' + crudo.slice(2);   // 0056… = +56…
  const d = crudo.replace(/\D/g, '');
  if (!d) return crudo.startsWith('+') ? '+' : '';
  let nacional = d;
  if (crudo.startsWith('+')) {
    if (!d.startsWith('56')) return d === '5' ? '+5' : '+' + d.slice(0, 15);   // "+5" aún puede ser +56
    nacional = d.slice(2);
  }
  // Ningún número chileno parte con 56: si aparece, es el código de país escrito de nuevo
  // (el campo ya trae "+56 " y la persona tipea 56 9…). Se descarta.
  for (let i = 0; i < 2 && nacional.startsWith('56'); i++) nacional = nacional.slice(2);
  nacional = nacional.replace(/^0+/, '').slice(0, 9);
  if (!nacional) return borrando ? '' : (crudo.startsWith('+') || d.startsWith('56') ? '+56 ' : '');
  return '+56 ' + agruparNacional(nacional);
}

function telefonoNacional(valor) {
  let d = String(valor == null ? '' : valor).replace(/\D/g, '');
  if (d.startsWith('56') && d.length > 9) d = d.slice(2);
  return d.replace(/^0+/, '');
}

function telefonoValidoCL(valor) {
  const crudo = String(valor == null ? '' : valor).trim();
  const d = crudo.replace(/\D/g, '');
  if (crudo.startsWith('+') && !d.startsWith('56')) return d.length >= 8 && d.length <= 15;   // otro país
  return telefonoNacional(valor).length === 9;
}

// ---- Formato único en TODA la app ----
// Cualquier casilla de RUT o teléfono (por su id o type="tel", incluidas las que aparecen en
// ventanas emergentes) se formatea sola al escribir. Para excluir una: data-formato="ninguno";
// para forzar una: data-formato="rut" | "telefono".
function tipoCampoChile(el) {
  if (!el || el.tagName !== 'INPUT') return null;
  const t = (el.type || 'text').toLowerCase();
  if (t !== 'text' && t !== 'tel') return null;
  const f = el.dataset && el.dataset.formato;
  if (f === 'ninguno') return null;
  if (f === 'rut' || f === 'telefono') return f;
  const id = (el.id || '').toLowerCase();
  if (/(^|[-_])(rut|dni)($|[-_])/.test(id)) return 'rut';   // AIVIMED guarda el RUT en la columna "dni"
  if (t === 'tel' || /(^|[-_])(tel|telefono|fono|celular|whatsapp|wa)($|[-_])/.test(id)) return 'telefono';
  return null;
}

function aplicarFormatoChile(el, borrando) {
  const tipo = tipoCampoChile(el);
  if (!tipo) return;
  const nuevo = tipo === 'rut' ? formatearRut(el.value) : formatearTelefonoCL(el.value, borrando);
  if (nuevo !== el.value) el.value = nuevo;
}

document.addEventListener('input', (e) => {
  aplicarFormatoChile(e.target, !!(e.inputType && e.inputType.startsWith('delete')));
});

// Datos cargados desde la base con otro formato quedan unificados al tocar la casilla
document.addEventListener('focusin', (e) => {
  if (e.target.value) aplicarFormatoChile(e.target, false);
});
