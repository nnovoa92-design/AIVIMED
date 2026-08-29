-- ============================================================
-- AIVIMED SaaS — Esquema multi-clínica (multi-tenant) con aislamiento
-- Ejecutar en el SQL Editor del PROYECTO SUPABASE NUEVO (dedicado).
--
-- Modelo de seguridad:
--  · Cada clínica es una "organización" (tenant).
--  · Cada tabla de datos tiene organizacion_id.
--  · RLS: cada usuario solo ve/edita las filas de SU organización.
--  · El súper-admin (creador) puede ver/gestionar todas.
--  · Las funciones current_org()/is_superadmin() son SECURITY DEFINER
--    para evitar recursión de RLS.
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- ORGANIZACIONES (clínicas / tenants)
-- ------------------------------------------------------------
create table organizaciones (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  slug text unique not null,              -- identificador para URLs públicas (ej: aivimed)
  rut text,
  direccion text,
  correo text,
  telefono text,
  instagram text,
  logo_url text,
  iva_pct numeric not null default 19,
  politica_cotizacion text,
  hora_apertura text default '09:30',
  hora_cierre text default '19:30',
  sab_apertura text default '10:00',
  sab_cierre text default '14:00',
  plan text not null default 'trial',     -- trial / activo / suspendido
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

-- ------------------------------------------------------------
-- PERFILES (usuarios) — 1:1 con auth.users
--  rol: superadmin (creador, sin organización) | admin (dueña de clínica)
--       | profesional | recepcion
-- ------------------------------------------------------------
create table perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  organizacion_id uuid references organizaciones(id) on delete cascade,  -- null solo para superadmin
  rol text not null default 'recepcion' check (rol in ('superadmin','admin','profesional','recepcion')),
  nombre text not null,
  email text,
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Helpers de seguridad (SECURITY DEFINER: no disparan RLS)
-- ------------------------------------------------------------
create or replace function current_org() returns uuid
language sql stable security definer set search_path = public as $$
  select organizacion_id from perfiles where id = auth.uid();
$$;

create or replace function current_rol() returns text
language sql stable security definer set search_path = public as $$
  select rol from perfiles where id = auth.uid();
$$;

create or replace function is_superadmin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from perfiles where id = auth.uid() and rol = 'superadmin');
$$;

-- Regla de acceso reutilizable: fila de mi organización, o soy superadmin
--  (se aplica como policy en cada tabla de datos)

-- ------------------------------------------------------------
-- RLS de organizaciones y perfiles
-- ------------------------------------------------------------
alter table organizaciones enable row level security;
-- Ver: superadmin ve todas; el resto ve solo la suya
create policy "org_select" on organizaciones for select
  using (is_superadmin() or id = current_org());
-- Crear/editar/borrar organizaciones: solo superadmin
create policy "org_write" on organizaciones for all
  using (is_superadmin()) with check (is_superadmin());

alter table perfiles enable row level security;
-- Ver: uno mismo, los de mi organización, o superadmin
create policy "perfiles_select" on perfiles for select
  using (id = auth.uid() or is_superadmin() or organizacion_id = current_org());
-- Gestionar usuarios: superadmin (todos) o admin dentro de su organización
create policy "perfiles_manage" on perfiles for all
  using (is_superadmin() or (current_rol() = 'admin' and organizacion_id = current_org()))
  with check (is_superadmin() or (current_rol() = 'admin' and organizacion_id = current_org()));

-- ============================================================
-- TABLAS DE DATOS (todas con organizacion_id + RLS de aislamiento)
-- ============================================================

-- Pacientes
create table pacientes (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  nombre text not null, apellido text not null, dni text,
  fecha_nacimiento date, telefono text, email text, direccion text,
  contacto_emergencia_nombre text, contacto_emergencia_telefono text,
  antecedentes text, observaciones text,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (organizacion_id, dni)
);

-- Catálogo
create table categorias_servicios (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  nombre text not null, descripcion text, orden integer not null default 0,
  unique (organizacion_id, nombre)
);
create table servicios (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  categoria_id uuid references categorias_servicios(id) on delete set null,
  nombre text not null, descripcion text, duracion_min integer, precio numeric(12,2),
  requiere_consentimiento boolean not null default false,
  consentimiento_template text,
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

-- Personal
create table personal (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  perfil_id uuid references perfiles(id) on delete set null,
  nombre text not null, apellido text not null, especialidad text,
  telefono text, email text, activo boolean not null default true,
  creado_en timestamptz not null default now()
);
create table personal_servicios (
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  personal_id uuid references personal(id) on delete cascade,
  servicio_id uuid references servicios(id) on delete cascade,
  primary key (personal_id, servicio_id)
);

-- Tratamientos / packs
create table tratamientos (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  paciente_id uuid not null references pacientes(id) on delete cascade,
  servicio_id uuid references servicios(id) on delete set null,
  total_sesiones int not null default 1, notas text,
  activo boolean not null default true, creado_en timestamptz not null default now()
);

-- Turnos
create table turnos (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  paciente_id uuid not null references pacientes(id) on delete cascade,
  servicio_id uuid references servicios(id) on delete set null,
  personal_id uuid references personal(id) on delete set null,
  fecha_hora timestamptz not null, duracion_min integer,
  estado text not null default 'pendiente'
    check (estado in ('pendiente','confirmado','completado','cancelado','ausente')),
  origen text not null default 'interno' check (origen in ('interno','online')),
  notas text, creado_en timestamptz not null default now()
);

-- Sesiones
create table sesiones (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  turno_id uuid references turnos(id) on delete set null,
  paciente_id uuid not null references pacientes(id) on delete cascade,
  servicio_id uuid references servicios(id) on delete set null,
  personal_id uuid references personal(id) on delete set null,
  personal_apoyo_id uuid references personal(id) on delete set null,
  tratamiento_id uuid references tratamientos(id) on delete set null,
  numero_sesion int, fecha timestamptz not null default now(),
  detalle text, observaciones text, fotos jsonb,
  creado_en timestamptz not null default now()
);

-- Insumos / stock
create table insumos (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  nombre text not null, unidad text not null default 'unidad',
  stock_actual numeric(12,2) not null default 0, stock_minimo numeric(12,2) not null default 0,
  precio_unitario numeric(12,2), activo boolean not null default true,
  creado_en timestamptz not null default now()
);
create table sesion_insumos (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  sesion_id uuid not null references sesiones(id) on delete cascade,
  insumo_id uuid not null references insumos(id) on delete restrict,
  cantidad numeric(12,2) not null, lote text
);
create table movimientos_stock (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  insumo_id uuid not null references insumos(id) on delete cascade,
  tipo text not null check (tipo in ('entrada','salida','ajuste')),
  cantidad numeric(12,2) not null, motivo text,
  sesion_id uuid references sesiones(id) on delete set null,
  fecha timestamptz not null default now()
);

-- Cotizaciones
create table cotizaciones (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  numero serial,
  paciente_id uuid not null references pacientes(id) on delete cascade,
  fecha timestamptz not null default now(),
  estado text not null default 'borrador' check (estado in ('borrador','enviada','aprobada','rechazada')),
  con_iva boolean not null default false, notas text, observacion text,
  creado_en timestamptz not null default now()
);
create table cotizacion_items (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  cotizacion_id uuid not null references cotizaciones(id) on delete cascade,
  servicio_id uuid references servicios(id) on delete set null,
  descripcion text not null, cantidad numeric(12,2) not null default 1,
  precio_unitario numeric(12,2) not null default 0, orden integer not null default 0
);

-- Pagos
create table pagos (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  paciente_id uuid not null references pacientes(id) on delete cascade,
  turno_id uuid references turnos(id) on delete set null,
  sesion_id uuid references sesiones(id) on delete set null,
  cotizacion_id uuid references cotizaciones(id) on delete set null,
  monto numeric(12,2) not null,
  metodo_pago text check (metodo_pago in ('efectivo','tarjeta_debito','tarjeta_credito','transferencia','otro')),
  con_iva boolean not null default false,
  tipo_documento text not null default 'ninguno' check (tipo_documento in ('ninguno','boleta','factura')),
  fecha timestamptz not null default now(), notas text
);

-- Consentimientos
create table consentimientos (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null references organizaciones(id) on delete cascade,
  paciente_id uuid not null references pacientes(id) on delete cascade,
  servicio_id uuid references servicios(id) on delete set null,
  sesion_id uuid references sesiones(id) on delete set null,
  fecha timestamptz not null default now(),
  texto_consentimiento text not null, firma_data text,
  firmado boolean not null default false, firmado_en timestamptz,
  firma_user_agent text, firma_ip text,
  nombre_firmante text, rut_firmante text,
  creado_en timestamptz not null default now()
);

-- ------------------------------------------------------------
-- RLS de aislamiento por organización en TODAS las tablas de datos
-- ------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'pacientes','categorias_servicios','servicios','personal','personal_servicios',
    'tratamientos','turnos','sesiones','insumos','sesion_insumos','movimientos_stock',
    'cotizaciones','cotizacion_items','pagos','consentimientos'
  ] loop
    execute format('alter table %I enable row level security', t);
    execute format(
      'create policy "org_isolation" on %I for all '
      || 'using (organizacion_id = current_org() or is_superadmin()) '
      || 'with check (organizacion_id = current_org() or is_superadmin())', t);
  end loop;
end $$;

-- ------------------------------------------------------------
-- Índices por organización (rendimiento del aislamiento)
-- ------------------------------------------------------------
create index on pacientes (organizacion_id);
create index on servicios (organizacion_id);
create index on turnos (organizacion_id, fecha_hora);
create index on sesiones (organizacion_id, fecha);
create index on cotizaciones (organizacion_id);
create index on pagos (organizacion_id, fecha);
create index on consentimientos (organizacion_id);
