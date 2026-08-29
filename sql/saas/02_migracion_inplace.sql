-- ============================================================
-- AIVIMED SaaS — Migración IN-PLACE del schema `bienestar` a multi-clínica
-- Ejecutar en el MISMO proyecto Supabase (SQL Editor).
--
-- ⚠️ ANTES DE EJECUTAR: exporta un respaldo de tus tablas (ver RESPALDO/RESPALDO.md).
-- Es seguro para AIVIMED: convierte a AIVIMED en la 1ª clínica, rellena
-- todos sus datos y activa el aislamiento por clínica. La app sigue funcionando.
-- ============================================================
set search_path to bienestar;

-- 1) Registro de organizaciones (clínicas / tenants)
create table if not exists organizaciones (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  slug text unique not null,
  plan text not null default 'activo',
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

-- 2) Crear la organización AIVIMED (idempotente)
insert into organizaciones (nombre, slug) values ('AIVIMED', 'aivimed')
on conflict (slug) do nothing;

-- 3) perfiles: agregar organizacion_id, email + permitir rol 'superadmin'
alter table perfiles add column if not exists organizacion_id uuid references organizaciones(id) on delete cascade;
alter table perfiles add column if not exists email text;
alter table perfiles drop constraint if exists perfiles_rol_check;
alter table perfiles add constraint perfiles_rol_check check (rol in ('superadmin','admin','profesional','recepcion'));

-- 4) Asegurar perfil ADMIN para la cuenta de la clínica dentro de AIVIMED
insert into perfiles (id, organizacion_id, rol, nombre, email)
select u.id, (select id from organizaciones where slug = 'aivimed'), 'admin', 'AIVIMED', u.email
from auth.users u
where u.email = 'aivimed.salud@gmail.com'
on conflict (id) do update
  set organizacion_id = (select id from organizaciones where slug = 'aivimed'),
      rol = 'admin';

-- 5) Helpers de seguridad (SECURITY DEFINER: no disparan RLS → evita recursión)
create or replace function current_org() returns uuid
  language sql stable security definer set search_path = bienestar as $$
  select organizacion_id from perfiles where id = auth.uid(); $$;
create or replace function current_rol() returns text
  language sql stable security definer set search_path = bienestar as $$
  select rol from perfiles where id = auth.uid(); $$;
create or replace function is_superadmin() returns boolean
  language sql stable security definer set search_path = bienestar as $$
  select exists (select 1 from perfiles where id = auth.uid() and rol = 'superadmin'); $$;
grant execute on function current_org(), current_rol(), is_superadmin() to authenticated, anon;

-- 6) Agregar organizacion_id a cada tabla de datos, rellenar con AIVIMED y fijar NOT NULL
do $$
declare t text; aivimed uuid;
begin
  select id into aivimed from organizaciones where slug = 'aivimed';
  foreach t in array array[
    'pacientes','categorias_servicios','servicios','personal','personal_servicios',
    'tratamientos','turnos','sesiones','insumos','sesion_insumos','movimientos_stock',
    'cotizaciones','cotizacion_items','pagos','consentimientos','config'
  ] loop
    execute format('alter table %I add column if not exists organizacion_id uuid references organizaciones(id) on delete cascade', t);
    execute format('update %I set organizacion_id = %L where organizacion_id is null', t, aivimed);
    execute format('alter table %I alter column organizacion_id set not null', t);
    execute format('create index if not exists %I on %I (organizacion_id)', 'idx_'||t||'_org', t);
  end loop;
end $$;

-- 7) Cambiar RLS: de "auth_full" (todos ven todo) a AISLAMIENTO POR CLÍNICA
do $$
declare t text;
begin
  foreach t in array array[
    'pacientes','categorias_servicios','servicios','personal','personal_servicios',
    'tratamientos','turnos','sesiones','insumos','sesion_insumos','movimientos_stock',
    'cotizaciones','cotizacion_items','pagos','consentimientos','config'
  ] loop
    execute format('drop policy if exists "auth_full" on %I', t);
    execute format(
      'create policy "org_isolation" on %I for all '
      || 'using (organizacion_id = current_org() or is_superadmin()) '
      || 'with check (organizacion_id = current_org() or is_superadmin())', t);
  end loop;
end $$;

-- 8) RLS de organizaciones y perfiles
alter table organizaciones enable row level security;
drop policy if exists "org_select" on organizaciones;
drop policy if exists "org_write" on organizaciones;
create policy "org_select" on organizaciones for select using (is_superadmin() or id = current_org());
create policy "org_write" on organizaciones for all using (is_superadmin()) with check (is_superadmin());

drop policy if exists "perfil_select" on perfiles;
drop policy if exists "perfil_update" on perfiles;
drop policy if exists "perfiles_select" on perfiles;
drop policy if exists "perfiles_manage" on perfiles;
create policy "perfiles_select" on perfiles for select
  using (id = auth.uid() or is_superadmin() or organizacion_id = current_org());
create policy "perfiles_manage" on perfiles for all
  using (is_superadmin() or (current_rol() = 'admin' and organizacion_id = current_org()))
  with check (is_superadmin() or (current_rol() = 'admin' and organizacion_id = current_org()));

reset search_path;

-- ============================================================
-- 9) (APARTE, cuando crees tu cuenta de SÚPER-ADMIN)
-- Crea primero el usuario en Authentication → Users → Add user con TU correo,
-- luego ejecuta ESTO reemplazando el correo:
--
--   insert into bienestar.perfiles (id, organizacion_id, rol, nombre, email)
--   select id, null, 'superadmin', 'Administrador', email
--   from auth.users where email = 'TU-CORREO-ADMIN@ejemplo.com'
--   on conflict (id) do update set rol = 'superadmin', organizacion_id = null;
-- ============================================================
