const SUPABASE_URL = 'https://qaeeqdfolgjobwxdpojd.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFhZWVxZGZvbGdqb2J3eGRwb2pkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExMjUxMDQsImV4cCI6MjA5NjcwMTEwNH0.HgGiUKN38A-anizmwPZOLftFBZXsyG862ibF2LwnRAs';

const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  db: { schema: 'bienestar' }
});

async function requireAuth() {
  const { data: { session } } = await supabaseClient.auth.getSession();
  if (!session) { window.location.href = '/index.html'; return null; }
  return session;
}

async function logout() {
  await supabaseClient.auth.signOut();
  window.location.href = '../index.html';
}

// Formato moneda Argentina
function fmtMoneda(n) {
  if (n == null || isNaN(Number(n))) return '–';
  return Number(n).toLocaleString('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 });
}

function fmtFecha(d) {
  if (!d) return '–';
  return new Date(d).toLocaleDateString('es-AR', { dateStyle: 'short' });
}

function fmtFechaHora(d) {
  if (!d) return '–';
  return new Date(d).toLocaleString('es-AR', { dateStyle: 'short', timeStyle: 'short' });
}
